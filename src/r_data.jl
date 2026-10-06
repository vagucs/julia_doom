# DOOM generic portado do python_doom para Julia com SDL2.
#
# Por Wagner Nunes da Silva
#
# vagucs@bol.com.br
# vagucs@vagucs.com.br
# vagucs@gmail.com
#
# www.vagucs.com.br
#
# Texturas, flats e COLORMAP, a partir de r_data.py.
# Os quadros de sprite ficam em sprites, preenchidos na vista.

module RData

using ..Compat
using ..Wad

export Resources, Post, new_resources, init!
export texture_num_for_name, flat_num_for_name, flat_pixels
export texture_height, texture_width, get_column, column_posts, colormap
export bind_pics, line_swatch

struct Post
    topdelta::Int
    pixels::Vector{UInt8}
end

struct TexPatch
    originx::Int
    originy::Int
    patch::Int
end

mutable struct Texture
    name::String
    width::Int
    height::Int
    patches::Vector{TexPatch}
    widthmask::Int
    composite::Union{Nothing,Vector{UInt8}}
    col_lump::Vector{Int}
    col_ofs::Vector{Int}
    post_cache::Dict{Int,Vector{Post}}
    col_cache::Dict{Int,Vector{UInt8}}
end

mutable struct Resources
    wad::WadFile
    textures::Vector{Texture}
    tex_index::Dict{String,Int}
    flats_first::Int
    flats_last::Int
    flattranslation::Vector{Int}
    texturetranslation::Vector{Int}
    colormaps::Vector{UInt8}
    cmap_cache::Vector{Union{Nothing,Vector{UInt8}}}
    flat_cache::Dict{Int,Vector{UInt8}}
    swatch::Dict{String,Int}
    skytexture::Int
    skyflatnum::Int
    sprites::Any
end

function new_resources(wad::WadFile)
    Resources(
        wad, Texture[], Dict{String,Int}(), 0, 0, Int[], Int[],
        UInt8[], Union{Nothing,Vector{UInt8}}[], Dict{Int,Vector{UInt8}}(),
        Dict{String,Int}(), 0, 0, nothing,
    )
end

function i16_at(buf::Vector{UInt8}, at::Int)
    i = at + 1
    v = Int(buf[i]) | (Int(buf[i + 1]) << 8)
    v >= 32768 ? v - 65536 : v
end

function i32_at(buf::Vector{UInt8}, at::Int)
    i = at + 1
    u = UInt32(buf[i]) | (UInt32(buf[i + 1]) << 8) | (UInt32(buf[i + 2]) << 16) | (UInt32(buf[i + 3]) << 24)
    Int(reinterpret(Int32, u))
end

function u32_at(buf::Vector{UInt8}, at::Int)
    i = at + 1
    Int(UInt32(buf[i]) | (UInt32(buf[i + 1]) << 8) | (UInt32(buf[i + 2]) << 16) | (UInt32(buf[i + 3]) << 24))
end

function name8(data::Vector{UInt8}, off::Int)
    raw = @view data[off + 1:off + 8]
    cut = findfirst(==(0x00), raw)
    bytes = cut === nothing ? raw : @view raw[1:cut - 1]
    uppercase(rstrip(String(Char.(bytes))))
end

function key8(name::AbstractString)
    key = uppercase(rstrip(name))
    cut = findfirst('\0', key)
    cut !== nothing && (key = key[1:cut - 1])
    chars = collect(key)
    length(chars) > 8 && (chars = chars[1:8])
    String(chars)
end

function colormap(res::Resources, level::Integer)
    level < 0 && (level = 0)
    level > 32 && (level = 32)
    if isempty(res.cmap_cache)
        res.cmap_cache = Union{Nothing,Vector{UInt8}}[nothing for _ in 1:33]
    end
    hit = res.cmap_cache[level + 1]
    hit !== nothing && return hit
    off = level * 256
    hit = res.colormaps[off + 1:off + 256]
    res.cmap_cache[level + 1] = hit
    hit
end

function init_flats(res::Resources)
    res.flats_first = get_num_for_name(res.wad, "F_START") + 1
    res.flats_last = get_num_for_name(res.wad, "F_END") - 1
    n = res.flats_last - res.flats_first + 1
    res.flattranslation = collect(0:n - 1)
end

function flat_num_for_name(res::Resources, name::AbstractString)
    i = check_num_for_name(res.wad, name)
    i < 0 && return 0
    i - res.flats_first
end

function flat_lump(res::Resources, flatnum::Integer)
    n = res.flats_last - res.flats_first + 1
    (flatnum < 0 || flatnum >= n) && (flatnum = 0)
    res.flats_first + res.flattranslation[flatnum + 1]
end

function flat_pixels(res::Resources, flatnum::Integer)
    lump = flat_lump(res, flatnum)
    hit = get(res.flat_cache, lump, nothing)
    hit !== nothing && return hit
    data = cache_lump_num(res.wad, lump)
    if length(data) >= 4096
        hit = data[1:4096]
    else
        hit = Vector{UInt8}(undef, 4096)
        copyto!(hit, data)
        hit[length(data) + 1:end] .= 0x00
    end
    res.flat_cache[lump] = hit
    hit
end

function generate_lookup(res::Resources, tex::Texture)
    width = tex.width
    patchcount = zeros(Int, width)
    for mp in tex.patches
        mp.patch < 0 && continue
        pdata = cache_lump_num(res.wad, mp.patch)
        pw = i16_at(pdata, 0)
        x1 = mp.originx
        x2 = x1 + pw
        x = x1 < 0 ? 0 : x1
        x2 > width && (x2 = width)
        while x < x2
            at = x + 1
            patchcount[at] += 1
            tex.col_lump[at] = mp.patch
            tex.col_ofs[at] = u32_at(pdata, 8 + (x - mp.originx) * 4)
            x += 1
        end
    end
    for x in 0:width - 1
        patchcount[x + 1] > 1 && (tex.col_lump[x + 1] = -1)
    end
end

function draw_column_in_cache(patch::Vector{UInt8}, column::Int, cache::Vector{UInt8}, x::Int, originy::Int, tex::Texture)
    while column < length(patch)
        topdelta = Int(patch[column + 1])
        topdelta == 255 && break
        length_post = Int(patch[column + 2])
        source = column + 3
        pos = originy + topdelta
        count = length_post
        if pos < 0
            count += pos
            source -= pos
            pos = 0
        end
        if pos + count > tex.height
            count = tex.height - pos
        end
        dest = x * tex.height + pos
        i = 0
        while i < count
            cache[dest + i + 1] = patch[source + i + 1]
            i += 1
        end
        column += length_post + 4
    end
end

function generate_composite(res::Resources, tex::Texture)
    tex.composite !== nothing && return
    buf = zeros(UInt8, tex.width * tex.height)
    for mp in tex.patches
        mp.patch < 0 && continue
        pdata = cache_lump_num(res.wad, mp.patch)
        pw = i16_at(pdata, 0)
        x1 = mp.originx
        x2 = x1 + pw
        x2 > tex.width && (x2 = tex.width)
        x = x1 < 0 ? 0 : x1
        while x < x2
            colofs = u32_at(pdata, 8 + (x - mp.originx) * 4)
            draw_column_in_cache(pdata, colofs, buf, x, mp.originy, tex)
            x += 1
        end
    end
    tex.composite = buf
    for x in 0:tex.width - 1
        if tex.col_lump[x + 1] < 0
            tex.col_ofs[x + 1] = x * tex.height
        end
    end
end

function init_textures(res::Resources)
    pnames = cache_lump_name(res.wad, "PNAMES")
    nummappatches = i32_at(pnames, 0)
    patchlookup = Vector{Int}(undef, nummappatches)
    for i in 0:nummappatches - 1
        patchlookup[i + 1] = check_num_for_name(res.wad, name8(pnames, 4 + i * 8))
    end
    maptex1 = cache_lump_name(res.wad, "TEXTURE1")
    numtextures1 = i32_at(maptex1, 0)
    maptex2 = UInt8[]
    numtextures2 = 0
    if check_num_for_name(res.wad, "TEXTURE2") >= 0
        maptex2 = cache_lump_name(res.wad, "TEXTURE2")
        numtextures2 = i32_at(maptex2, 0)
    end
    empty!(res.textures)
    empty!(res.tex_index)
    for i in 0:numtextures1 + numtextures2 - 1
        offset, src = if i < numtextures1
            i32_at(maptex1, 4 + i * 4), maptex1
        else
            i32_at(maptex2, 4 + (i - numtextures1) * 4), maptex2
        end
        width = i16_at(src, offset + 12)
        height = i16_at(src, offset + 14)
        patchcount = i16_at(src, offset + 20)
        patches = TexPatch[]
        poff = offset + 22
        for _ in 1:patchcount
            ox = i16_at(src, poff)
            oy = i16_at(src, poff + 2)
            pidx = i16_at(src, poff + 4)
            poff += 10
            lump = -1
            if 0 <= pidx < nummappatches
                lump = patchlookup[pidx + 1]
            end
            push!(patches, TexPatch(ox, oy, lump))
        end
        j = 1
        while j * 2 <= width
            j *= 2
        end
        tex = Texture(
            name8(src, offset), width, height, patches, j - 1, nothing,
            fill(-1, width), zeros(Int, width),
            Dict{Int,Vector{Post}}(), Dict{Int,Vector{UInt8}}(),
        )
        res.tex_index[tex.name] = length(res.textures)
        push!(res.textures, tex)
        generate_lookup(res, tex)
    end
    res.texturetranslation = collect(0:length(res.textures) - 1)
end

function texture_num_for_name(res::Resources, name::AbstractString)
    key = key8(name)
    (key == "-" || key == "") && return 0
    get(res.tex_index, key, 0)
end

texture_height(res::Resources, texnum::Integer) = res.textures[texnum + 1].height * Int(FRACUNIT)

texture_width(res::Resources, texnum::Integer) = res.textures[texnum + 1].width

function column_posts(res::Resources, texnum::Integer, col::Integer)
    (texnum <= 0 || texnum >= length(res.textures)) && return Post[]
    tex = res.textures[texnum + 1]
    col = Int(band(col, tex.widthmask))
    hit = get(tex.post_cache, col, nothing)
    hit !== nothing && return hit
    lump = tex.col_lump[col + 1]
    posts = Post[]
    if lump >= 0
        patch = cache_lump_num(res.wad, lump)
        column = tex.col_ofs[col + 1]
        while column < length(patch)
            topdelta = Int(patch[column + 1])
            topdelta == 255 && break
            length_post = Int(patch[column + 2])
            source = column + 3
            push!(posts, Post(topdelta, patch[source + 1:source + length_post]))
            column += length_post + 4
        end
        tex.post_cache[col] = posts
        return posts
    end
    generate_composite(res, tex)
    ofs = tex.col_ofs[col + 1]
    colbytes = tex.composite[ofs + 1:ofs + tex.height]
    if !isempty(colbytes)
        push!(posts, Post(0, colbytes))
    end
    tex.post_cache[col] = posts
    posts
end

function column_to_source(patch::Vector{UInt8}, column::Int)
    buf = zeros(UInt8, 128)
    while column < length(patch)
        topdelta = Int(patch[column + 1])
        topdelta == 255 && break
        length_post = Int(patch[column + 2])
        source = column + 3
        for i in 0:length_post - 1
            y = topdelta + i
            if 0 <= y < 128
                buf[y + 1] = patch[source + i + 1]
            end
        end
        column += length_post + 4
    end
    buf
end

function repeat_column(colbytes::AbstractVector{UInt8})
    buf = zeros(UInt8, 128)
    n = length(colbytes)
    if n > 0
        for i in 0:127
            buf[i + 1] = colbytes[mod(i, n) + 1]
        end
    end
    buf
end

function get_column(res::Resources, texnum::Integer, col::Integer)
    tex = res.textures[texnum + 1]
    col = Int(band(col, tex.widthmask))
    hit = get(tex.col_cache, col, nothing)
    hit !== nothing && return hit
    lump = tex.col_lump[col + 1]
    if lump >= 0
        pdata = cache_lump_num(res.wad, lump)
        hit = column_to_source(pdata, tex.col_ofs[col + 1])
    else
        generate_composite(res, tex)
        ofs = tex.col_ofs[col + 1]
        hit = repeat_column(tex.composite[ofs + 1:ofs + tex.height])
    end
    tex.col_cache[col] = hit
    hit
end

function init!(res::Resources)
    init_textures(res)
    init_flats(res)
    res.colormaps = cache_lump_name(res.wad, "COLORMAP")
    res.cmap_cache = Union{Nothing,Vector{UInt8}}[]
    empty!(res.flat_cache)
    empty!(res.swatch)
    res.skyflatnum = flat_num_for_name(res, "F_SKY1")
    res.skytexture = texture_num_for_name(res, "SKY1")
    res
end

function bind_pics(res::Resources, world)
    for sec in world.sectors
        sec.floorpic = flat_num_for_name(res, sec.floorflat)
        sec.ceilingpic = flat_num_for_name(res, sec.ceilingflat)
    end
    for side in world.sides
        side.toptexture = texture_num_for_name(res, side.topname)
        side.bottomtexture = texture_num_for_name(res, side.bottomname)
        side.midtexture = texture_num_for_name(res, side.midname)
    end
    world
end

function dominant(pixels::AbstractVector{UInt8})
    counts = Dict{UInt8,Int}()
    best = UInt8(0)
    bestn = 0
    for c in pixels
        c == 0x00 && continue
        n = get(counts, c, 0) + 1
        counts[c] = n
        if n > bestn
            bestn = n
            best = c
        end
    end
    bestn == 0 && return isempty(pixels) ? 4 : Int(pixels[1])
    Int(best)
end

function swatch(res::Resources, kind::AbstractString, num::Integer)
    key = string(kind, num)
    hit = get(res.swatch, key, nothing)
    hit !== nothing && return hit
    pixels = kind == "t" ? get_column(res, num, 0) : flat_pixels(res, num)
    hit = dominant(pixels)
    res.swatch[key] = hit
    hit
end

function line_swatch(res::Resources, ln, plain::Integer, open::Integer)
    side = ln.sides[1]
    side === nothing && return open
    num = side.midtexture
    num <= 0 && (num = side.toptexture)
    num <= 0 && (num = side.bottomtexture)
    if num > 0
        return swatch(res, "t", num)
    end
    side.sector === nothing && return open
    swatch(res, "f", side.sector.floorpic)
end

end

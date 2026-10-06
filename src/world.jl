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
# Mapa a partir de world.py. Nomes de textura ficam no setor e no lado.
# O numero da textura entra na fase 7, quando r_data existir.

module World

using ..Compat
using ..Wad
using ..VVideo

export ML_TWOSIDED, NF_SUBSECTOR
export new_world, setup_level, player_start, point_in_subsector, draw_overhead

const ML_TWOSIDED = 4
const NF_SUBSECTOR = 32768
const BOXLEFT = 1
const BOXRIGHT = 2
const BOXBOTTOM = 3
const BOXTOP = 4

const MAPVERTEX_SIZE = 4
const MAPSEG_SIZE = 12
const MAPSUBSECTOR_SIZE = 4
const MAPSECTOR_SIZE = 26
const MAPNODE_SIZE = 28
const MAPTHING_SIZE = 10
const MAPLINEDEF_SIZE = 14
const MAPSIDEDEF_SIZE = 30

mutable struct Vertex
    x::Int32
    y::Int32
end

mutable struct Sector
    floorheight::Int32
    ceilingheight::Int32
    floorflat::String
    ceilingflat::String
    floorpic::Int
    ceilingpic::Int
    lightlevel::Int
    special::Int
    tag::Int
    lines::Vector{Any}
    i_sector::Int
    specialdata::Any
    validcount::Int
    soundtraversed::Int
    soundtarget::Any
end

mutable struct Side
    textureoffset::Int32
    rowoffset::Int32
    topname::String
    bottomname::String
    midname::String
    toptexture::Int
    bottomtexture::Int
    midtexture::Int
    sector::Sector
end

mutable struct Line
    v1::Vertex
    v2::Vertex
    dx::Int32
    dy::Int32
    flags::Int
    special::Int
    tag::Int
    sidenum::Vector{Int}
    bbox::Vector{Int32}
    frontsector::Union{Nothing,Sector}
    backsector::Union{Nothing,Sector}
    sides::Vector{Union{Nothing,Side}}
    i_line::Int
    validcount::Int
end

mutable struct Seg
    v1::Vertex
    v2::Vertex
    offset::Int32
    angle::UInt32
    sidedef::Union{Nothing,Side}
    linedef::Line
    frontsector::Union{Nothing,Sector}
    backsector::Union{Nothing,Sector}
end

mutable struct Subsector
    numlines::Int
    firstline::Int
    sector::Union{Nothing,Sector}
end

mutable struct Node
    x::Int32
    y::Int32
    dx::Int32
    dy::Int32
    bbox::Vector{Vector{Int32}}
    children::Vector{Int}
end

mutable struct MapThing
    x::Int
    y::Int
    angle::Int
    type::Int
    options::Int
end

mutable struct MapWorld
    vertexes::Vector{Vertex}
    sectors::Vector{Sector}
    sides::Vector{Side}
    lines::Vector{Line}
    segs::Vector{Seg}
    subsectors::Vector{Subsector}
    nodes::Vector{Node}
    things::Vector{MapThing}
    numnodes::Int
    blockmap::Vector{Int}
    bmaporgx::Int32
    bmaporgy::Int32
    bmapwidth::Int
    bmapheight::Int
    blockmaplump::Vector{Int}
    rejectmatrix::Vector{UInt8}
    mapname::String
    mobjs::Vector{Any}
    blocklinks::Vector{Any}
    validcount::Int
end

new_world() = MapWorld(
    Vertex[], Sector[], Side[], Line[], Seg[], Subsector[], Node[], MapThing[],
    0, Int[], Int32(0), Int32(0), 0, 0, Int[], UInt8[], "", Any[], Any[], 0,
)

function i16_at(buf::Vector{UInt8}, at::Int)
    i = at + 1
    v = Int(buf[i]) | (Int(buf[i + 1]) << 8)
    v >= 32768 ? v - 65536 : v
end

function u16_at(buf::Vector{UInt8}, at::Int)
    i = at + 1
    Int(buf[i]) | (Int(buf[i + 1]) << 8)
end

fixed(n::Integer) = as_i32(Int64(n) * Int64(FRACUNIT))

function name8(data::Vector{UInt8}, off::Int)
    raw = @view data[off + 1:off + 8]
    cut = findfirst(==(0x00), raw)
    bytes = cut === nothing ? raw : @view raw[1:cut - 1]
    uppercase(rstrip(String(Char.(bytes))))
end

function load_vertexes(world::MapWorld, data::Vector{UInt8})
    n = length(data) ÷ MAPVERTEX_SIZE
    world.vertexes = Vector{Vertex}(undef, n)
    for i in 0:n - 1
        world.vertexes[i + 1] = Vertex(fixed(i16_at(data, i * 4)), fixed(i16_at(data, i * 4 + 2)))
    end
end

function load_sectors(world::MapWorld, data::Vector{UInt8})
    n = length(data) ÷ MAPSECTOR_SIZE
    world.sectors = Vector{Sector}(undef, n)
    for i in 0:n - 1
        o = i * MAPSECTOR_SIZE
        world.sectors[i + 1] = Sector(
            fixed(i16_at(data, o)),
            fixed(i16_at(data, o + 2)),
            name8(data, o + 4),
            name8(data, o + 12),
            0,
            0,
            i16_at(data, o + 20),
            i16_at(data, o + 22),
            i16_at(data, o + 24),
            Any[],
            i,
            nothing,
            0,
            0,
            nothing,
        )
    end
end

function load_sides(world::MapWorld, data::Vector{UInt8})
    n = length(data) ÷ MAPSIDEDEF_SIZE
    nsec = length(world.sectors)
    world.sides = Vector{Side}(undef, n)
    for i in 0:n - 1
        o = i * MAPSIDEDEF_SIZE
        sec = i16_at(data, o + 28)
        sector = world.sectors[1]
        if 0 <= sec < nsec
            sector = world.sectors[sec + 1]
        end
        world.sides[i + 1] = Side(
            fixed(i16_at(data, o)),
            fixed(i16_at(data, o + 2)),
            name8(data, o + 4),
            name8(data, o + 12),
            name8(data, o + 20),
            0,
            0,
            0,
            sector,
        )
    end
end

function load_lines(world::MapWorld, data::Vector{UInt8})
    n = length(data) ÷ MAPLINEDEF_SIZE
    world.lines = Vector{Line}(undef, n)
    for i in 0:n - 1
        o = i * MAPLINEDEF_SIZE
        v1 = world.vertexes[i16_at(data, o) + 1]
        v2 = world.vertexes[i16_at(data, o + 2) + 1]
        s0 = i16_at(data, o + 10)
        s1 = i16_at(data, o + 12)
        side0 = s0 >= 0 ? world.sides[s0 + 1] : nothing
        side1 = s1 >= 0 ? world.sides[s1 + 1] : nothing
        front = side0 === nothing ? nothing : side0.sector
        back = side1 === nothing ? nothing : side1.sector
        bbox = Vector{Int32}(undef, 4)
        if v1.x < v2.x
            bbox[BOXLEFT] = v1.x
            bbox[BOXRIGHT] = v2.x
        else
            bbox[BOXLEFT] = v2.x
            bbox[BOXRIGHT] = v1.x
        end
        if v1.y < v2.y
            bbox[BOXBOTTOM] = v1.y
            bbox[BOXTOP] = v2.y
        else
            bbox[BOXBOTTOM] = v2.y
            bbox[BOXTOP] = v1.y
        end
        ln = Line(
            v1, v2,
            as_i32(Int(v2.x) - Int(v1.x)),
            as_i32(Int(v2.y) - Int(v1.y)),
            i16_at(data, o + 4),
            i16_at(data, o + 6),
            i16_at(data, o + 8),
            [s0, s1],
            bbox,
            front,
            back,
            Union{Nothing,Side}[side0, side1],
            i,
            0,
        )
        if front !== nothing
            push!(front.lines, ln)
        end
        if back !== nothing && back !== front
            push!(back.lines, ln)
        end
        world.lines[i + 1] = ln
    end
end

function load_segs(world::MapWorld, data::Vector{UInt8})
    n = length(data) ÷ MAPSEG_SIZE
    world.segs = Vector{Seg}(undef, n)
    for i in 0:n - 1
        o = i * MAPSEG_SIZE
        ln = world.lines[i16_at(data, o + 6) + 1]
        side = i16_at(data, o + 8)
        sd = ln.sides[side + 1]
        sd === nothing && (sd = ln.sides[1])
        front = sd === nothing ? nothing : sd.sector
        back = nothing
        if band(ln.flags, ML_TWOSIDED) != 0
            other = ln.sides[xor(side, 1) + 1]
            other !== nothing && (back = other.sector)
        end
        world.segs[i + 1] = Seg(
            world.vertexes[i16_at(data, o) + 1],
            world.vertexes[i16_at(data, o + 2) + 1],
            fixed(i16_at(data, o + 10)),
            as_u32(Int64(i16_at(data, o + 4)) << 16),
            sd,
            ln,
            front,
            back,
        )
    end
end

function load_subsectors(world::MapWorld, data::Vector{UInt8})
    n = length(data) ÷ MAPSUBSECTOR_SIZE
    world.subsectors = Vector{Subsector}(undef, n)
    for i in 0:n - 1
        o = i * MAPSUBSECTOR_SIZE
        world.subsectors[i + 1] = Subsector(u16_at(data, o), u16_at(data, o + 2), nothing)
    end
end

function load_nodes(world::MapWorld, data::Vector{UInt8})
    n = length(data) ÷ MAPNODE_SIZE
    world.nodes = Vector{Node}(undef, n)
    for i in 0:n - 1
        o = i * MAPNODE_SIZE
        bbox = Vector{Vector{Int32}}(undef, 2)
        p = o + 8
        for child in 1:2
            bbox[child] = Int32[
                fixed(i16_at(data, p)),
                fixed(i16_at(data, p + 2)),
                fixed(i16_at(data, p + 4)),
                fixed(i16_at(data, p + 6)),
            ]
            p += 8
        end
        world.nodes[i + 1] = Node(
            fixed(i16_at(data, o)),
            fixed(i16_at(data, o + 2)),
            fixed(i16_at(data, o + 4)),
            fixed(i16_at(data, o + 6)),
            bbox,
            [u16_at(data, p), u16_at(data, p + 2)],
        )
    end
end

function load_things(world::MapWorld, data::Vector{UInt8})
    n = length(data) ÷ MAPTHING_SIZE
    world.things = Vector{MapThing}(undef, n)
    for i in 0:n - 1
        o = i * MAPTHING_SIZE
        world.things[i + 1] = MapThing(
            i16_at(data, o),
            i16_at(data, o + 2),
            i16_at(data, o + 4),
            i16_at(data, o + 6),
            i16_at(data, o + 8),
        )
    end
end

function load_blockmap(world::MapWorld, data::Vector{UInt8})
    n = length(data) ÷ 2
    lump = Vector{Int}(undef, n)
    for i in 0:n - 1
        lump[i + 1] = u16_at(data, i * 2)
    end
    world.blockmaplump = lump
    world.blockmap = Int[]
    n < 4 && return
    world.bmaporgx = fixed(i16_at(data, 0))
    world.bmaporgy = fixed(i16_at(data, 2))
    world.bmapwidth = i16_at(data, 4)
    world.bmapheight = i16_at(data, 6)
    count = world.bmapwidth * world.bmapheight
    world.blockmap = Vector{Int}(undef, count)
    for i in 1:count
        world.blockmap[i] = lump[4 + i]
    end
end

load_reject(world::MapWorld, data::Vector{UInt8}) = (world.rejectmatrix = data)

function setup_level(world::MapWorld, wad::WadFile, episode::Integer, mapn::Integer)
    empty!(world.mobjs)
    lumpname = check_num_for_name(wad, "MAP$(lpad(mapn, 2, '0'))") >= 0 ?
        "MAP$(lpad(mapn, 2, '0'))" : "E$(episode)M$(mapn)"
    lumpnum = get_num_for_name(wad, lumpname)
    load_vertexes(world, cache_lump_num(wad, lumpnum + 4))
    load_sectors(world, cache_lump_num(wad, lumpnum + 8))
    load_sides(world, cache_lump_num(wad, lumpnum + 3))
    load_lines(world, cache_lump_num(wad, lumpnum + 2))
    load_segs(world, cache_lump_num(wad, lumpnum + 5))
    load_subsectors(world, cache_lump_num(wad, lumpnum + 6))
    load_nodes(world, cache_lump_num(wad, lumpnum + 7))
    load_things(world, cache_lump_num(wad, lumpnum + 1))
    load_blockmap(world, cache_lump_num(wad, lumpnum + 10))
    load_reject(world, cache_lump_num(wad, lumpnum + 9))
    world.numnodes = length(world.nodes)
    world.mapname = lumpname
    world.validcount = 0
    world.blocklinks = Vector{Any}(nothing, max(0, world.bmapwidth * world.bmapheight))
    for ss in world.subsectors
        seg = world.segs[ss.firstline + 1]
        ss.sector = seg.frontsector
    end
    world
end

function player_start(world::MapWorld)
    for thing in world.things
        thing.type == 1 && return thing
    end
    isempty(world.things) ? nothing : world.things[1]
end

function point_in_subsector(world::MapWorld, x::Integer, y::Integer)
    nodenum = world.numnodes - 1
    nodenum < 0 && return world.subsectors[1]
    while band(nodenum, NF_SUBSECTOR) == 0
        node = world.nodes[nodenum + 1]
        dx = as_i32(Int(x) - Int(node.x))
        dy = as_i32(Int(y) - Int(node.y))
        left = Int(as_i32(shar(node.dy, 16))) * Int(dx)
        right = Int(dy) * Int(as_i32(shar(node.dx, 16)))
        side = right >= left ? 1 : 0
        nodenum = node.children[side + 1]
    end
    world.subsectors[Int(band(nodenum, 32767)) + 1]
end

function pick_colors(pal::AbstractVector{UInt8})
    wall, open, arrow = 4, 4, 4
    best, mid, red = -1, 1000000000, -1
    for i in 0:255
        r = Int(pal[i * 3 + 1])
        g = Int(pal[i * 3 + 2])
        b = Int(pal[i * 3 + 3])
        sum = r + g + b
        if sum > best
            best = sum
            wall = i
        end
        spread = abs(r - g) + abs(g - b) + abs(r - b)
        if spread < 24 && sum > 180 && sum < 520
            dist = abs(sum - 320)
            if dist < mid
                mid = dist
                open = i
            end
        end
        if r > red && r > g + 80 && r > b + 80
            red = r
            arrow = i
        end
    end
    mid == 1000000000 && (open = wall)
    wall, open, arrow
end

function map_scale(world::MapWorld)
    minx = typemax(Float64)
    maxx = typemin(Float64)
    miny = minx
    maxy = maxx
    for v in world.vertexes
        x = Float64(v.x) / Float64(FRACUNIT)
        y = Float64(v.y) / Float64(FRACUNIT)
        x < minx && (minx = x)
        x > maxx && (maxx = x)
        y < miny && (miny = y)
        y > maxy && (maxy = y)
    end
    spanx = max(1.0, maxx - minx)
    spany = max(1.0, maxy - miny)
    margin = 8
    scale = (SCREENWIDTH - margin * 2) / spanx
    sy = (SCREENHEIGHT - margin * 2) / spany
    sy < scale && (scale = sy)
    ox = (SCREENWIDTH - spanx * scale) / 2
    oy = (SCREENHEIGHT - spany * scale) / 2
    minx, maxy, scale, ox, oy
end

function draw_overhead(world::MapWorld, fb::Vector{UInt8}, pal::AbstractVector{UInt8}, color_of::Union{Nothing,Function}=nothing)
    plain, open, arrow = pick_colors(pal)
    minx, maxy, scale, ox, oy = map_scale(world)
    to_screen(x, y) = (ox + (x - minx) * scale, oy + (maxy - y) * scale)
    for ln in world.lines
        color = if color_of === nothing
            ln.backsector === nothing ? plain : open
        else
            color_of(ln, plain, open)
        end
        x0, y0 = to_screen(Float64(ln.v1.x) / Float64(FRACUNIT), Float64(ln.v1.y) / Float64(FRACUNIT))
        x1, y1 = to_screen(Float64(ln.v2.x) / Float64(FRACUNIT), Float64(ln.v2.y) / Float64(FRACUNIT))
        draw_line(fb, x0, y0, x1, y1, color)
    end
    ps = player_start(world)
    if ps !== nothing
        rad = ps.angle * pi / 180
        x0, y0 = to_screen(Float64(ps.x), Float64(ps.y))
        x1, y1 = to_screen(ps.x + cos(rad) * 128, ps.y + sin(rad) * 128)
        draw_line(fb, x0, y0, x1, y1, arrow)
        plot(fb, x0, y0, arrow)
    end
    fb
end

end

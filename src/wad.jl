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
# Leitor de WAD (wad.py). O numero do lump continua 0-based.
# O vetor do Julia e 1-based, entao a leitura soma 1.
# O miolo do lump fica em Vector{UInt8}.

module Wad

export WadFile, find_iwad, add_file!
export num_lumps, check_num_for_name, get_num_for_name
export lump_length, cache_lump_num, cache_lump_name, lump_name

const IWAD_NAMES = (
    "DOOM1.WAD",
    "doom1.wad",
    "DOOM.WAD",
    "doom.wad",
    "DOOM2.WAD",
    "doom2.wad",
    "PLUTONIA.WAD",
    "TNT.WAD",
    "freedoom1.wad",
    "freedoom2.wad",
)

mutable struct Lump
    name::String
    position::UInt32
    size::UInt32
    cache::Union{Nothing,Vector{UInt8}}
    wad_path::String
end

mutable struct WadFile
    lumps::Vector{Lump}
    index::Dict{String,Int}
end

WadFile() = WadFile(Lump[], Dict{String,Int}())

function u32_at(buf::Vector{UInt8}, at::Int)
    i = at + 1
    UInt32(buf[i]) |
    (UInt32(buf[i + 1]) << 8) |
    (UInt32(buf[i + 2]) << 16) |
    (UInt32(buf[i + 3]) << 24)
end

function latin1(raw::AbstractVector{UInt8})
    String(Char.(raw))
end

function name8(raw::AbstractVector{UInt8})
    cut = findfirst(==(0x00), raw)
    if cut !== nothing
        raw = @view raw[1:cut - 1]
    end
    uppercase(rstrip(latin1(raw)))
end

function key_of(name::AbstractString)
    cut = findfirst('\0', name)
    if cut !== nothing
        name = name[1:cut - 1]
    end
    name = uppercase(rstrip(name))
    if ncodeunits(name) > 8
        name = name[1:8]
    end
    name
end

function find_iwad(explicit::AbstractString="")
    if !isempty(explicit)
        isfile(explicit) || error("IWAD not found: $explicit")
        return abspath(explicit)
    end
    env = get(ENV, "DOOMWADDIR", get(ENV, "DOOMWADPATH", ""))
    here = dirname(@__DIR__)
    roots = String[]
    isempty(env) || push!(roots, env)
    push!(roots, pwd(), here, dirname(here), dirname(dirname(here)))
    for root in roots
        for name in IWAD_NAMES
            path = joinpath(root, name)
            isfile(path) && return abspath(path)
        end
    end
    error("No IWAD found. Put doom1.wad in this folder or pass -iwad file.wad")
end

function add_file!(wad::WadFile, path::AbstractString)
    path = abspath(path)
    header = Vector{UInt8}(undef, 12)
    directory = Vector{UInt8}()
    open(path, "r") do io
        readbytes!(io, header) == 12 || error("not a WAD: $path")
        ident = latin1(@view header[1:4])
        ident == "IWAD" || ident == "PWAD" || error("not a WAD: $path")
        numlumps = Int(u32_at(header, 4))
        infotable = Int(u32_at(header, 8))
        seek(io, infotable)
        directory = read(io, numlumps * 16)
        length(directory) == numlumps * 16 || error("truncated WAD directory: $path")
    end
    start = length(wad.lumps)
    numlumps = length(directory) ÷ 16
    for i in 0:numlumps - 1
        off = i * 16
        push!(wad.lumps, Lump(
            name8(@view directory[off + 9:off + 16]),
            u32_at(directory, off),
            u32_at(directory, off + 4),
            nothing,
            path,
        ))
    end
    for i in start:(length(wad.lumps) - 1)
        wad.index[wad.lumps[i + 1].name] = i
    end
    wad
end

num_lumps(wad::WadFile) = length(wad.lumps)

function check_num_for_name(wad::WadFile, name::AbstractString)
    get(wad.index, key_of(name), -1)
end

function get_num_for_name(wad::WadFile, name::AbstractString)
    n = check_num_for_name(wad, name)
    n < 0 && error("lump not found: $name")
    n
end

lump_length(wad::WadFile, num::Integer) = Int(wad.lumps[num + 1].size)

function cache_lump_num(wad::WadFile, num::Integer)
    lump = wad.lumps[num + 1]
    if lump.cache === nothing
        data = Vector{UInt8}(undef, Int(lump.size))
        open(lump.wad_path, "r") do io
            seek(io, Int(lump.position))
            n = Int(lump.size)
            n == 0 || readbytes!(io, data) == n || error("short lump: $(lump.name)")
        end
        lump.cache = data
    end
    lump.cache
end

cache_lump_name(wad::WadFile, name::AbstractString) = cache_lump_num(wad, get_num_for_name(wad, name))

lump_name(wad::WadFile, num::Integer) = wad.lumps[num + 1].name

end

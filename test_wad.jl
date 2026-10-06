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
# Teste de wad.jl. Sem janela.

include(joinpath(@__DIR__, "src", "wad.jl"))
using .Wad

function eq(name, got, want)
    got == want || error("$name got $got want $want")
end

path = find_iwad()
wad = WadFile()
add_file!(wad, path)

pal_num = get_num_for_name(wad, "playpal")
title_num = get_num_for_name(wad, "TITLEPIC")
pal = cache_lump_name(wad, "PLAYPAL")
title = cache_lump_num(wad, title_num)

eq("pal", length(pal), 10752)
eq("pal-len", length(pal), lump_length(wad, pal_num))
eq("title", length(title), 68168)
eq("title-len", length(title), lump_length(wad, title_num))
eq("el", eltype(pal), UInt8)
cache_lump_name(wad, "PLAYPAL") === pal || error("cache miss")
eq("miss", check_num_for_name(wad, "NO_SUCH_LUMP"), -1)
num_lumps(wad) >= 1 || error("empty directory")
lump_name(wad, 0) == "" && error("empty name")
eq("lumps", num_lumps(wad), 1264)

println("wad ok $path lumps $(num_lumps(wad)) pal $(length(pal)) title $(length(title))")

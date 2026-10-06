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
# Teste do titulo. Sem janela.

include(joinpath(@__DIR__, "src", "wad.jl"))
include(joinpath(@__DIR__, "src", "v_video.jl"))
using .Wad
using .VVideo

wad = WadFile()
add_file!(wad, find_iwad())
pal = cache_lump_name(wad, "PLAYPAL")
title = cache_lump_name(wad, "TITLEPIC")
length(pal) >= 768 || error("PLAYPAL curta")

width, height, left, top = patch_size(title)
(width == 320 && height == 200) || error("TITLEPIC $(width)x$(height)")
left == 0 && top == 0 || error("TITLEPIC offset $left,$top")

fb = new_fb()
draw_patch(fb, 0, 0, title)
ink = count(!=(0x00), fb)
ink >= 10000 || error("titulo vazio $ink")
length(fb) == PIXELS || error("framebuffer $(length(fb))")

println("title ok $(width)x$(height) ink $ink")

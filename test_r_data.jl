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
# Teste de texturas e flats. Sem janela.

include(joinpath(@__DIR__, "src", "compat.jl"))
include(joinpath(@__DIR__, "src", "wad.jl"))
include(joinpath(@__DIR__, "src", "v_video.jl"))
include(joinpath(@__DIR__, "src", "r_data.jl"))
include(joinpath(@__DIR__, "src", "world.jl"))
using .Wad
using .VVideo
using .RData
using .World

function eq(name, got, want)
    got == want || error("$name got $got want $want")
end

wad = WadFile()
add_file!(wad, find_iwad())
res = new_resources(wad)
init!(res)

eq("ntex", length(res.textures), 125)
eq("nflats", length(res.flattranslation), 56)
t0 = res.textures[1]
eq("name0", t0.name, "AASTINKY")
eq("w0", t0.width, 24)
eq("h0", t0.height, 72)
eq("mask0", t0.widthmask, 15)
eq("patches0", length(t0.patches), 2)
eq("STARTAN2", texture_num_for_name(res, "STARTAN2"), 69)
eq("BROWN1", texture_num_for_name(res, "BROWN1"), 14)
eq("dash", texture_num_for_name(res, "-"), 0)
eq("missing", texture_num_for_name(res, "NOTEX"), 0)
eq("noflat", flat_num_for_name(res, "NOFLAT"), 0)

start = res.textures[70]
eq("sw", start.width, 128)
eq("smask", start.widthmask, 127)
eq("slump", start.col_lump[1], 1117)
eq("sofs", start.col_ofs[1], 136)
col = get_column(res, 69, 0)
eq("clen", length(col), 128)
eq("c0", col[1], 143)
eq("c64", col[65], 141)
posts = column_posts(res, 69, 0)
eq("ptop", posts[1].topdelta, 0)
eq("p0", posts[1].pixels[1], 143)

eq("big", res.textures[2].name, "BIGDOOR1")
big = get_column(res, 1, 0)
eq("blen", length(big), 128)
eq("b0", big[1], 107)
eq("b10", big[11], 104)
bposts = column_posts(res, 1, 3)
eq("btop", bposts[1].topdelta, 0)
eq("bplen", length(bposts[1].pixels), 96)
eq("bp0", bposts[1].pixels[1], 107)

eq("FLOOR4_8", flat_num_for_name(res, "FLOOR4_8"), 10)
eq("skyflat", res.skyflatnum, 54)
eq("skytex", res.skytexture, 59)
flat = flat_pixels(res, 10)
eq("flen", length(flat), 4096)
eq("fcenter", flat[32 * 64 + 32 + 1], 1)
eq("theight", texture_height(res, 69), 8388608)
eq("twidth", texture_width(res, 69), 128)
eq("cmap", length(res.colormaps), 8704)
cm0 = colormap(res, 0)
eq("cm0", length(cm0), 256)
eq("cm0a", cm0[1], 0)
eq("cm0b", cm0[256], 255)
eq("cm32", colormap(res, 32)[1], 4)

world = new_world()
setup_level(world, wad, 1, 1)
bind_pics(res, world)
eq("floorpic", world.sectors[1].floorpic, 10)
eq("ceilpic", world.sectors[1].ceilingpic, 32)
eq("midtex", world.sides[1].midtexture, 30)
eq("door", res.textures[world.sides[1].midtexture + 1].name, "DOOR3")

fb = new_fb()
pal = cache_lump_name(wad, "PLAYPAL")
draw_overhead(world, fb, pal, (ln, plain, open) -> line_swatch(res, ln, plain, open))
ink = count(!=(0x00), fb)
kinds = length(unique(filter(!=(0x00), fb)))
kinds < 4 && error("planta com poucas cores: $kinds")

println("r_data ok texturas $(length(res.textures)) flats $(length(res.flattranslation)) tinta $ink cores $kinds")

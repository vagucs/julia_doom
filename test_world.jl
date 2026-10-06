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
# Teste do mapa E1M1. Sem janela. Sem numero de textura.

include(joinpath(@__DIR__, "src", "compat.jl"))
include(joinpath(@__DIR__, "src", "wad.jl"))
include(joinpath(@__DIR__, "src", "v_video.jl"))
include(joinpath(@__DIR__, "src", "world.jl"))
using .Wad
using .VVideo
using .World

function eq(name, got, want)
    got == want || error("$name got $got want $want")
end

wad = WadFile()
add_file!(wad, find_iwad())
world = new_world()
setup_level(world, wad, 1, 1)

eq("map", world.mapname, "E1M1")
eq("vertexes", length(world.vertexes), 467)
eq("sectors", length(world.sectors), 85)
eq("sides", length(world.sides), 648)
eq("lines", length(world.lines), 475)
eq("segs", length(world.segs), 732)
eq("subsectors", length(world.subsectors), 237)
eq("nodes", length(world.nodes), 236)
eq("things", length(world.things), 138)
eq("numnodes", world.numnodes, 236)

v0 = world.vertexes[1]
eq("v0x", v0.x, 71303168)
eq("v0y", v0.y, -241172480)

sec = world.sectors[1]
eq("floor", sec.floorheight, 0)
eq("ceil", sec.ceilingheight, 4718592)
eq("light", sec.lightlevel, 160)
eq("seclines", length(sec.lines), 4)
eq("floorflat", sec.floorflat, "FLOOR4_8")
eq("ceilflat", sec.ceilingflat, "CEIL3_5")

ln = world.lines[1]
eq("flags", ln.flags, 1)
eq("dx", ln.dx, -4194304)
eq("dy", ln.dy, 0)
eq("s0", ln.sidenum[1], 0)
eq("s1", ln.sidenum[2], -1)
eq("bleft", ln.bbox[1], 67108864)
eq("bright", ln.bbox[2], 71303168)
eq("bbot", ln.bbox[3], -241172480)
eq("btop", ln.bbox[4], -241172480)
eq("front", ln.frontsector.i_sector, 40)
ln.backsector === nothing || error("linha 0 tem fundo")

sg = world.segs[1]
eq("angle", sg.angle, 1073741824)
eq("offset", sg.offset, 0)
eq("segfront", sg.frontsector.i_sector, 0)
eq("segback", sg.backsector.i_sector, 4)

nd = world.nodes[1]
eq("nx", nd.x, 101711872)
eq("ny", nd.y, -159383552)
eq("ndx", nd.dx, 7340032)
eq("ndy", nd.dy, 0)
eq("c0", nd.children[1], 32768)
eq("c1", nd.children[2], 32769)
eq("ntop", nd.bbox[1][1], -159383552)
eq("nbot", nd.bbox[1][2], -167772160)
eq("nleft", nd.bbox[1][3], 101711872)
eq("nright", nd.bbox[1][4], 109051904)

th = world.things[1]
eq("tx", th.x, 1056)
eq("ty", th.y, -3616)
eq("ta", th.angle, 90)
eq("tt", th.type, 1)
eq("to", th.options, 7)
ps = player_start(world)
eq("px", ps.x, 1056)
eq("py", ps.y, -3616)

eq("bmapx", world.bmaporgx, -50855936)
eq("bmapy", world.bmaporgy, -319291392)
eq("bmapw", world.bmapwidth, 36)
eq("bmaph", world.bmapheight, 23)
eq("bmapn", length(world.blockmap), 828)
eq("blump", length(world.blockmaplump), 3461)
eq("boff", world.blockmap[1], 832)
eq("reject", length(world.rejectmatrix), 904)
eq("r0", world.rejectmatrix[1], 32)
eq("ssn", world.subsectors[1].numlines, 4)
eq("ssf", world.subsectors[1].firstline, 0)
eq("sss", world.subsectors[1].sector.i_sector, 0)
eq("side0", world.sides[1].sector.i_sector, 40)
eq("midname", world.sides[1].midname, "DOOR3")

fb = new_fb()
pal = cache_lump_name(wad, "PLAYPAL")
draw_overhead(world, fb, pal)
ink = count(!=(0x00), fb)
ink < 1000 && error("planta quase vazia: $ink")
kinds = length(unique(filter(!=(0x00), fb)))
kinds < 2 && error("planta com poucas cores: $kinds")
println("world ok E1M1 linhas $(length(world.lines)) tinta $ink cores $kinds")

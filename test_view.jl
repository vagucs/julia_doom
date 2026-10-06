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
# Vista do E1M1 igual ao Lua, que bate com o Python. Sem janela.

include(joinpath(@__DIR__, "src", "compat.jl"))
include(joinpath(@__DIR__, "src", "wad.jl"))
include(joinpath(@__DIR__, "src", "v_video.jl"))
include(joinpath(@__DIR__, "src", "tables.jl"))
include(joinpath(@__DIR__, "src", "r_data.jl"))
include(joinpath(@__DIR__, "src", "world.jl"))
include(joinpath(@__DIR__, "src", "render.jl"))
include(joinpath(@__DIR__, "src", "sprites.jl"))
using .Wad
using .VVideo
using .RData
using .World
using .Render
using .Sprites

function eq(name, got, want)
    got == want || error("$name got $got want $want")
end

wad = WadFile()
add_file!(wad, find_iwad())
res = new_resources(wad)
init!(res)
world = new_world()
setup_level(world, wad, 1, 1)
bind_pics(res, world)
ps = player_start(world)
x = ps.x * 65536
y = ps.y * 65536
ang = fld(ps.angle * 536870912, 45)
sub = point_in_subsector(world, x, y)
z = Int(sub.sector.floorheight) + 41 * 65536
eq("sec", sub.sector.i_sector, 38)
eq("z", z, 2686976)
eq("ang", ang, 1073741824)

r = new_renderer(res)
set_view_size!(r, 10, 0)
setup_frame!(r, x, y, z, ang, 0, 0)
fb = new_fb()
render_view!(r, world, fb)
oracle = read(joinpath(@__DIR__, "_view_walls.bin"))
length(oracle) == 64000 || error("oracle $(length(oracle))")
function compare_fb(fb, oracle)
    bad = 0
    first = 0
    ink = 0
    for i in 1:64000
        fb[i] != 0x00 && (ink += 1)
        if fb[i] != oracle[i]
            bad += 1
            first == 0 && (first = i)
        end
    end
    bad, first, ink
end

bad, first, ink = compare_fb(fb, oracle)
if bad != 0
    ypix = fld(first - 1, 320)
    xpix = (first - 1) % 320
    error("vista diferente em $bad pixels, primeiro $first ($xpix,$ypix) julia $(fb[first]) lua $(oracle[first]) tinta $ink segs $(length(r.drawsegs)) planos $(length(r.visplanes))")
end
println("view ok tinta $ink segs $(length(r.drawsegs)) planos $(length(r.visplanes))")

init_defs!(res)
spawn_things!(world, 2)
eq("mobs", length(world.mobjs), 91)
draw!(r, world, fb)
draw_masked!(r)
spr = read(joinpath(@__DIR__, "_view_spr.bin"))
length(spr) == 64000 || error("oracle spr $(length(spr))")
bad, first, ink = compare_fb(fb, spr)
if bad != 0
    ypix = fld(first - 1, 320)
    xpix = (first - 1) % 320
    error("sprite diferente em $bad pixels, primeiro $first ($xpix,$ypix) julia $(fb[first]) lua $(spr[first]) tinta $ink")
end
println("sprites ok tinta $ink coisas $(length(world.mobjs))")

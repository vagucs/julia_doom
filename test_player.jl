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
# Andar, atirar e a pistola na frente da vista, iguais ao Lua e ao Python. Sem janela.

include(joinpath(@__DIR__, "src", "compat.jl"))
include(joinpath(@__DIR__, "src", "wad.jl"))
include(joinpath(@__DIR__, "src", "v_video.jl"))
include(joinpath(@__DIR__, "src", "video.jl"))
include(joinpath(@__DIR__, "src", "mus2mid.jl"))
include(joinpath(@__DIR__, "src", "sound.jl"))
include(joinpath(@__DIR__, "src", "game.jl"))
include(joinpath(@__DIR__, "src", "tables.jl"))
include(joinpath(@__DIR__, "src", "r_data.jl"))
include(joinpath(@__DIR__, "src", "world.jl"))
include(joinpath(@__DIR__, "src", "render.jl"))
include(joinpath(@__DIR__, "src", "sprites.jl"))
include(joinpath(@__DIR__, "src", "random.jl"))
include(joinpath(@__DIR__, "src", "collision.jl"))
include(joinpath(@__DIR__, "src", "player.jl"))
using .Wad
using .VVideo
using .Snd
using .GameMod
using .RData
using .World
using .Render
using .Sprites
using .Rng
using .Collision
using .Player

function eq(name, got, want)
    got == want || error("$name got $got want $want")
end

wad = WadFile()
add_file!(wad, find_iwad())
res = new_resources(wad)
init!(res)
init_defs!(res)

function boot()
    world = new_world()
    setup_level(world, wad, 1, 1)
    bind_pics(res, world)
    spawn_things!(world, 2)
    link_mobjs!(world)
    rng_clear!()
    player = spawn_player(world, player_start(world), 0)
    game = new_game()
    game.world = world
    game.res = res
    game.skill = 2
    game.damage_mobj = damage_mobj
    game.start_sound = _ -> nothing
    world, player, game
end

world, player, game = boot()
for tic in 0:34
    player.cmd = TicCmd(25, 0, 0, 0)
    think!(world, player, game, tic)
end
mo = player.mo
eq("x", mo.x, 69200415)
eq("y", mo.y, -222974830)
eq("z", mo.z, 0)
eq("momx", mo.momx, -193)
eq("momy", mo.momy, 479135)
eq("ang", mo.angle, 1073741824)
eq("viewz", player.viewz, 2272651)
eq("arma", player.psprite_state, "ready")
println("andar ok $(mo.x) $(mo.y)")

world, player, game = boot()
for tic in 0:19
    player.cmd = TicCmd(0, 0, 0, 0)
    think!(world, player, game, tic)
end
r = new_renderer(res)
set_view_size!(r, 10, 0)
setup_frame!(r, player.mo.x, player.mo.y, player.viewz, player.mo.angle, 0, 0)
fb = new_fb()
render_view!(r, world, fb)
draw!(r, world, fb)
draw_masked!(r)
draw_weapon!(r, fb, player, 20)
oracle = read(joinpath(@__DIR__, "_player.bin"))
length(oracle) == 64000 || error("oracle $(length(oracle))")
function count_diff(fb, oracle)
    bad = 0
    ink = 0
    for i in 1:64000
        fb[i] != 0x00 && (ink += 1)
        fb[i] != oracle[i] && (bad += 1)
    end
    bad, ink
end

bad, ink = count_diff(fb, oracle)
bad == 0 || error("arma diferente em $bad pixels tinta $ink")
println("arma ok tinta $ink")

world, player, game = boot()
for tic in 0:39
    buttons = tic >= 20 ? 1 : 0
    player.cmd = TicCmd(0, 0, 0, buttons)
    think!(world, player, game, tic)
    tick_fx!(world)
end
function living_health(world, player)
    health = 0
    for th in world.mobjs
        (th.fx || th === player.mo) && continue
        health += th.health
    end
    health
end

health = living_health(world, player)
eq("municao", player.ammo[1], 49)
eq("vida", health, 79320)
eq("tiro", player.psprite_state, "atk")
println("tiro ok municao $(player.ammo[1]) vida $health")

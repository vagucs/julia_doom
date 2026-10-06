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
# Inimigos do E1M1 depois de 20 tics parados, iguais ao Lua e ao Python. Sem janela.

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
include(joinpath(@__DIR__, "src", "specials.jl"))
include(joinpath(@__DIR__, "src", "info.jl"))
include(joinpath(@__DIR__, "src", "thinker.jl"))
include(joinpath(@__DIR__, "src", "enemy.jl"))
using .Wad
using .RData
using .World
using .Rng
using .Specials
using .GameMod
using .Snd
using .Player
using .Thinker
using .Enemy

function sig(world)
    n = 0
    for (i, mo) in enumerate(world.mobjs)
        (mo.player !== nothing || mo.fx) && continue
        n = mod(n + mo.typ + mo.x + mo.y * 3 + mo.z * 5 + mo.health * 7 + mo.frame * 11 + mo.flags * 13 + mo.istate * 17 + mo.height + i, 1000000007)
        n = mod(n + length(mo.sprite) * 19, 1000000007)
    end
    n
end

function main()
    wad = WadFile()
    add_file!(wad, find_iwad())
    res = new_resources(wad)
    init!(res)
    rng_clear!()
    world = new_world()
    setup_level(world, wad, 1, 1)
    bind_pics(res, world)
    game = new_game()
    game.skill = 2
    game.episode = 1
    game.mapn = 1
    game.res = res
    game.world = world
    game.leveltime = 0
    game.start_sound = _ -> nothing
    game.specials = new_specials(world, res, nothing)
    game.damage_mobj = (target, source, damage, inflictor=source) -> Enemy.damage_mobj(game, target, source, damage, inflictor)
    game.use_special = (line, thing, side) -> use_special(game.specials, line, thing, side)
    spawn_map!(world, 2, game)
    apply_fast!(game)
    for _ in 1:20
        game.player.cmd = empty_cmd()
        think!(world, game.player, game, game.leveltime)
        tick_actors!(world, game)
        tick!(game.specials)
        game.leveltime += 1
    end
    idle = sig(world)
    victim = nothing
    for mo in world.mobjs
        if mo.sprite == "POSS" && mo.health > 0
            victim = mo
            break
        end
    end
    game.damage_mobj(victim, game.player.mo, 10000, game.player.mo)
    dead = "$(victim.sprite),$(victim.frame),$(victim.health),$(victim.height),$(victim.flags)"
    idle == 357442092 || error("posicao $idle")
    dead == "POSS,12,-9980,917504,5243938" || error("corpo $dead")
    println("inimigos ok corpo POSS")
end

main()

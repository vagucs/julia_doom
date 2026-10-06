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
# Porta, luzes e a saida do E1M1, iguais ao Lua e ao Python. Sem janela.

include(joinpath(@__DIR__, "src", "compat.jl"))
include(joinpath(@__DIR__, "src", "wad.jl"))
include(joinpath(@__DIR__, "src", "v_video.jl"))
include(joinpath(@__DIR__, "src", "r_data.jl"))
include(joinpath(@__DIR__, "src", "world.jl"))
include(joinpath(@__DIR__, "src", "tables.jl"))
include(joinpath(@__DIR__, "src", "render.jl"))
include(joinpath(@__DIR__, "src", "sprites.jl"))
include(joinpath(@__DIR__, "src", "random.jl"))
include(joinpath(@__DIR__, "src", "collision.jl"))
include(joinpath(@__DIR__, "src", "specials.jl"))
using .Wad
using .RData
using .World
using .Rng
using .Specials

function main()
    wad = WadFile()
    add_file!(wad, find_iwad())
    res = new_resources(wad)
    init!(res)
    world = new_world()
    setup_level(world, wad, 1, 1)
    bind_pics(res, world)
    rng_clear!()
    spec = new_specials(world, res, nothing)
    for _ in 1:20
        tick!(spec)
    end
    door = nothing
    for ln in world.lines
        if ln.special == 1
            door = ln
            break
        end
    end
    before = Int(door.sides[2].sector.ceilingheight)
    use_special(spec, door, nothing, 0)
    for _ in 1:30
        tick!(spec)
    end
    after = Int(door.sides[2].sector.ceilingheight)
    sum = 0
    for (i, s) in enumerate(world.sectors)
        sum = (sum + Int(s.floorheight) + Int(s.ceilingheight) * 3 + s.lightlevel * 5 + s.special * 7 + i) % 1000000007
    end
    exit_line = nothing
    for ln in world.lines
        if ln.special == 11
            exit_line = ln
            break
        end
    end
    use_special(spec, exit_line, nothing, 0)
    mid = exit_line.sides[1].midtexture
    before == 0 || error("teto inicial $before")
    after == 3932160 || error("teto $after")
    sum == 919240412 || error("soma $sum")
    mid == 119 || error("textura $mid")
    spec.exit_requested || error("saida")
    println("setores ok porta $before -> $after saida $(spec.exit_requested)")
end

main()

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
# Barra, contagem e derretimento. Sem janela.

include(joinpath(@__DIR__, "src", "compat.jl"))
include(joinpath(@__DIR__, "src", "wad.jl"))
include(joinpath(@__DIR__, "src", "v_video.jl"))
include(joinpath(@__DIR__, "src", "tables.jl"))
include(joinpath(@__DIR__, "src", "r_data.jl"))
include(joinpath(@__DIR__, "src", "world.jl"))
include(joinpath(@__DIR__, "src", "render.jl"))
include(joinpath(@__DIR__, "src", "sprites.jl"))
include(joinpath(@__DIR__, "src", "random.jl"))
include(joinpath(@__DIR__, "src", "collision.jl"))
include(joinpath(@__DIR__, "src", "status.jl"))
include(joinpath(@__DIR__, "src", "wipe.jl"))
include(joinpath(@__DIR__, "src", "wi_stuff.jl"))
using .Wad
using .VVideo
using .Status
using .Wipe
using .Wi

mutable struct FacePlayer
    health::Int
    armorpoints::Int
    readyweapon::Int
    ammo::Vector{Int}
    maxammo::Vector{Int}
    weaponowned::Vector{Bool}
    cards::Vector{Bool}
    message::String
    bonuscount::Int
    damagecount::Int
    attackdown::Bool
    cheats::Int
    powers::Vector{Int}
    attacker::Any
    mo::Any
end

function sig(fb)
    sum = 0
    roll = 0
    for b in fb
        sum += Int(b)
        roll = mod(roll * 33 + Int(b), 4294967296)
    end
    sum, roll
end

function main()
    partime(1, 1, false) == 1050 || error("par E1M1")
    partime(1, 2, false) == 75 * 35 || error("par E1M2")
    wipe = new_wipe()
    fb = new_fb()
    wipe.start = fill(UInt8(1), PIXELS)
    wipe.endfb = fill(UInt8(2), PIXELS)
    wipe.y = fill(200, 160)
    wipe.y[1] = 0
    tick_wipe!(wipe, 1, fb) == false || error("melt segue")
    (fb[1] == 2 && fb[2] == 2) || error("topo novo")
    fb[321] == 1 || error("resto velho")
    wipe.y[1] == 1 || error("coluna andou")
    wipe.y[1] = -2
    tick_wipe!(wipe, 1, fb) == false || error("atraso")
    (wipe.y[1] == -1 && fb[1] == 1) || error("coluna parada")
    wad = WadFile()
    add_file!(wad, find_iwad())
    bar = new_status(wad)
    player = FacePlayer(100, 0, 1, [50, 0, 0, 0], [200, 50, 300, 50],
        [true, true, false, false, false, false, false, false, false],
        fill(false, 6), "", 0, 0, false, 0, zeros(Int, 6), nothing, nothing)
    fill!(fb, 0x00)
    draw_status!(bar, fb, player, true)
    sum, roll = sig(fb)
    Status.ticker!(bar, player)
    (bar.face_index == 0 && bar.face_count == 16 && bar.rnd == 1103527590) || error("rosto $(bar.face_index) $(bar.face_count) $(bar.rnd)")
    fill!(fb, 0x00)
    draw_status!(bar, fb, player, true)
    sum2, roll2 = sig(fb)
    (sum == 1083692 && roll == 2753326764) || error("barra $sum $roll")
    (sum2 == sum && roll2 == roll) || error("barra depois do tic")
    game = (wad = wad, menu = nothing, player = nothing, held = Dict{String,Bool}(), start_sound = _ -> nothing, sound = (change_music = (_, _) -> nothing,))
    wi = new_wi(game, Wi.Board(0, 0, 1, 10, 5, 1, 1050, 0, 0, 0, 350, false, false))
    fill!(fb, 0x00)
    draw_wi!(wi, fb)
    wsum, wroll = sig(fb)
    (wsum == 8593360 && wroll == 1838591568) || error("contagem $wsum $wroll")
    game.held["return"] = true
    Wi.ticker!(wi)
    wi.sp_state == 10 || error("atalho")
    (wi.cnt_kills == 0 && wi.cnt_items == 0 && wi.cnt_secret == 0) || error("porcentagem")
    (wi.cnt_time == 10 && wi.cnt_par == 30) || error("tempo")
    println("hud ok barra 1083692 contagem 8593360")
end

main()

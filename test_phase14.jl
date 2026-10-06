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
# Cheats, automapa, finale e save. Sem janela.

include(joinpath(@__DIR__, "src", "compat.jl"))
include(joinpath(@__DIR__, "src", "wad.jl"))
include(joinpath(@__DIR__, "src", "v_video.jl"))
include(joinpath(@__DIR__, "src", "mus2mid.jl"))
include(joinpath(@__DIR__, "src", "video.jl"))
include(joinpath(@__DIR__, "src", "sound.jl"))
include(joinpath(@__DIR__, "src", "tables.jl"))
include(joinpath(@__DIR__, "src", "r_data.jl"))
include(joinpath(@__DIR__, "src", "world.jl"))
include(joinpath(@__DIR__, "src", "render.jl"))
include(joinpath(@__DIR__, "src", "sprites.jl"))
include(joinpath(@__DIR__, "src", "random.jl"))
include(joinpath(@__DIR__, "src", "collision.jl"))
include(joinpath(@__DIR__, "src", "player.jl"))
include(joinpath(@__DIR__, "src", "info.jl"))
include(joinpath(@__DIR__, "src", "am_map.jl"))
include(joinpath(@__DIR__, "src", "cheats.jl"))
include(joinpath(@__DIR__, "src", "finale.jl"))
include(joinpath(@__DIR__, "src", "saveg.jl"))
using .Wad
using .VVideo
using .World
using .RData
using .Player
using .Automap
using .Cheats
using .Finale
using .Saveg

function eq(name, got, want)
    got == want || error("$name got $got want $want")
end

mutable struct MiniMo
    health::Int
    flags::Int
    angle::Int
    x::Int
    y::Int
end

mutable struct CheatPlayer
    cheats::Int
    health::Int
    armorpoints::Int
    armortype::Int
    mo::Any
    powers::Vector{Int}
    weaponowned::Vector{Bool}
    ammo::Vector{Int}
    maxammo::Vector{Int}
    cards::Vector{Bool}
    message::String
    message_tics::Int
    readyweapon::Int
    pendingweapon::Int
end

function fresh_player()
    CheatPlayer(0, 50, 0, 0, MiniMo(50, 0, 90, 16, 32),
        zeros(Int, 6),
        [true, true, false, false, false, false, false, false, false],
        [10, 0, 0, 0], [200, 50, 300, 50], fill(false, 6),
        "", 0, 1, 10)
end

mutable struct PhaseGame
    gamestate::String
    skill::Int
    wad::Any
    sound::Any
    player::Any
    world::Any
    mapn::Int
    episode::Int
    res::Any
    iwad_path::String
    leveltime::Int
    nocheats::Bool
    menu::Any
    automap::Any
    start_level::Any
    specials::Any
    totalkills::Int
    totalitems::Int
    totalsecret::Int
    held::Any
    mouse_fire::Bool
    force_wipe::Bool
    carry::Any
end

function feed(box, text, game)
    for ch in text
        feed!(box, string(ch), game)
    end
end

function main()
    w = WadFile()
    add_file!(w, find_iwad())
    game = PhaseGame("view", 2, w, (change_music = (_, _) -> nothing, play = _ -> nothing),
        nothing, nothing, 1, 1, nothing, "", 0, false, nothing, nothing, nothing, nothing,
        0, 0, 0, Dict{String,Bool}(), false, false, nothing)
    p = fresh_player()
    game.player = p
    box = new_cheats()
    feed(box, "iddqd", game)
    eq("god", p.cheats, 2)
    eq("godmsg", p.message, "Degreelessness Mode On")
    eq("godhp", p.health, 100)
    p = fresh_player()
    game.player = p
    game.skill = 4
    box = new_cheats()
    feed(box, "iddqd", game)
    eq("nightmare", p.cheats, 0)
    game.skill = 2
    p = fresh_player()
    game.player = p
    box = new_cheats()
    feed(box, "idkfa", game)
    eq("ammo", p.ammo[1], 200)
    eq("card", p.cards[1], true)
    eq("saw", p.weaponowned[8], true)
    text = encode([
        "episode" => 1, "name" => "E1M1", "ok" => true, "ammo" => [50, 0],
    ])
    decoded = decode(text)
    eq("json ep", decoded["episode"], 1)
    eq("json name", decoded["name"], "E1M1")
    eq("json ok", decoded["ok"], true)
    eq("json ammo", decoded["ammo"][1], 50)
    res = new_resources(w)
    init!(res)
    world = new_world()
    setup_level(world, w, 1, 1)
    start = player_start(world)
    player = spawn_player(world, start)
    game.world = world
    game.player = player
    game.mapn = 1
    game.episode = 1
    game.res = res
    am = new_automap()
    start!(am, game)
    am.cheating = 1
    fb = new_fb()
    drawer!(am, fb, game)
    ink = count(b -> b != 0, @view fb[1:320 * 168])
    ink >= 1000 || error("automapa tinta $ink")
    fin = new_finale(game)
    eq("texto", fin.text[1:8], "Once you")
    eq("flat", fin.flat, "FLOOR4_8")
    for _ in 1:3
        Finale.ticker!(fin)
    end
    eq("count", fin.count, 3)
    fill!(fb, 0x00)
    draw_finale!(fin, fb)
    letters = count(b -> b != 0, @view fb[1:320 * 40])
    letters >= 10 || error("finale sem letras $letters")
    dir = joinpath(get(ENV, "TEMP", "."), "doomphase14")
    mkpath(dir)
    game.iwad_path = joinpath(dir, "DOOM1.WAD")
    game.leveltime = 35
    write_save(game, 0, "E1M1") || error("gravou")
    desc, ok = description(game, 0)
    eq("desc", desc, "E1M1")
    eq("slot", ok, true)
    data = read_save(game, 0)
    eq("save ep", data["episode"], 1)
    eq("save map", data["mapn"], 1)
    eq("save hp", data["player"]["health"], 100)
    eq("save time", data["leveltime"], 35)
    rm(path(game, 0))
    println("fase14 ok cheats mapa $ink finale $letters")
end

main()

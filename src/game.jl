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
# Estado do jogo. A skill escolhida chama start_level quando ele existe.

module GameMod

using ..Snd

export Game, new_game

mutable struct Game
    running::Bool
    gamestate::String
    show_messages::Bool
    detail_level::Int
    screen_size::Int
    mouse_sensitivity::Int
    skill::Int
    episode::Int
    mapn::Int
    sound::Sound
    world::Any
    start_level::Any
    player::Any
    leveltime::Int
    res::Any
    damage_mobj::Any
    start_sound::Any
    touch_special::Any
    cross_special::Any
    use_special::Any
    shoot_special::Any
    turnheld::Int
    specials::Any
    carry::Any
    pending_map::Int
    exit_wait::Int
    was_secret::Bool
    fastparm::Bool
    respawnparm::Bool
    nomonsters::Bool
    respawnmonsters::Bool
    noise_alert::Any
    fire_missile::Any
    totalkills::Int
    totalitems::Int
    totalsecret::Int
    wad::Any
    menu::Any
    automap::Any
    cheatbox::Any
    statusbar::Any
    wipe::Any
    wi::Any
    finale::Any
    held::Any
    iwad_path::String
    wiping::Bool
    force_wipe::Bool
    wipe_state::String
    show_fps::Bool
    crt::Bool
    nocheats::Bool
    use_mouse::Bool
    mousex::Int
    mousey::Int
    mouse_fire::Bool
    fps_text::String
    st_palette::Int
    save_game::Any
    load_game::Any
    slot_desc::Any
    end_game::Any
end

function new_game(sound::Sound=new_sound())
    Game(
        true, "title", true, 0, 7, 5, 2, 1, 1, sound, nothing, nothing,
        nothing, 0, nothing, nothing, nothing, nothing, nothing, nothing, nothing, 0,
        nothing, nothing, 1, 0, false,
        false, false, false, false, nothing, nothing,
        0, 0, 0,
        nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing,
        "", false, false, "", false, false, false, true, 0, 0, false, "0 FPS", 0,
        nothing, nothing, nothing, nothing,
    )
end

end

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
# Menu do titulo, a partir de menu.py. Escolher a skill nao abre o mapa.

module Menu

using ..Wad
using ..VVideo
using ..Snd
using ..GameMod

export new_menu, responder, ticker, draw

const LINEHEIGHT = 16
const SKULLXOFF = -32
const SAVESTRINGSIZE = 24
const LOADSAVEEMPTY = "empty slot"

mutable struct MenuItem
    status::Int
    name::String
    action::String
    alpha::Int
end

mutable struct MenuDef
    items::Vector{MenuItem}
    routine::String
    x::Int
    y::Int
    last_on::Int
    prev::Union{Nothing,String}
end

mutable struct MenuState
    wad::WadFile
    sound::Sound
    game::Game
    active::Bool
    screen::String
    item_on::Int
    which_skull::Int
    skull_tics::Int
    epi::Int
    message::Union{Nothing,String}
    message_confirm::Bool
    message_action::Union{Nothing,String}
    save_strings::Vector{String}
    menus::Dict{String,MenuDef}
end

item(status, name, action, alpha=0) = MenuItem(status, name, action, alpha)

function menu_def(items, routine, x, y, last_on=0, prev=nothing)
    MenuDef(items, routine, x, y, last_on, prev)
end

has_episodes(wad::WadFile) = check_num_for_name(wad, "MAP01") < 0

has_lump(menu::MenuState, name::AbstractString) = check_num_for_name(menu.wad, name) >= 0

function patch(menu::MenuState, name::AbstractString)
    n = check_num_for_name(menu.wad, name)
    n < 0 && return nothing
    cache_lump_num(menu.wad, n)
end

function new_menu(wad::WadFile, sound::Sound, game::Game)
    slots = [item(1, "", "loadslot") for _ in 1:6]
    save_slots = [item(1, "", "saveslot") for _ in 1:6]
    menus = Dict{String,MenuDef}(
        "main" => menu_def([
            item(1, "M_NGAME", "newgame", 110),
            item(1, "M_OPTION", "options", 111),
            item(1, "M_LOADG", "loadgame", 108),
            item(1, "M_SAVEG", "savegame", 115),
            item(1, "M_RDTHIS", "readthis", 114),
            item(1, "M_QUITG", "quit", 113),
        ], "main", 97, 64),
        "episode" => menu_def([
            item(1, "M_EPI1", "episode", 107),
            item(1, "M_EPI2", "episode", 116),
            item(1, "M_EPI3", "episode", 105),
            item(1, "M_EPI4", "episode", 116),
        ], "episode", 48, 63, 0, "main"),
        "skill" => menu_def([
            item(1, "M_JKILL", "skill", 105),
            item(1, "M_ROUGH", "skill", 104),
            item(1, "M_HURT", "skill", 104),
            item(1, "M_ULTRA", "skill", 117),
            item(1, "M_NMARE", "skill", 110),
        ], "skill", 48, 63, 2, "episode"),
        "options" => menu_def([
            item(1, "M_ENDGAM", "endgame", 101),
            item(1, "M_MESSG", "messages", 109),
            item(1, "M_DETAIL", "detail", 103),
            item(2, "M_SCRNSZ", "scrnsize", 115),
            item(-1, "", "", 0),
            item(2, "M_MSENS", "mousesens", 109),
            item(-1, "", "", 0),
            item(1, "M_SVOL", "sound", 115),
        ], "options", 60, 37, 0, "main"),
        "sound" => menu_def([
            item(2, "M_SFXVOL", "sfxvol", 115),
            item(-1, "", "", 0),
            item(2, "M_MUSVOL", "musvol", 109),
            item(-1, "", "", 0),
        ], "sound", 80, 64, 0, "options"),
        "load" => menu_def(slots, "load", 80, 54, 0, "main"),
        "save" => menu_def(save_slots, "save", 80, 54, 0, "main"),
        "read1" => menu_def([item(1, "", "read2", 0)], "read1", 280, 185, 0, "main"),
        "read2" => menu_def([item(1, "", "finishread", 0)], "read2", 330, 175, 0, "read1"),
    )
    if !has_episodes(wad)
        menus["skill"].prev = "main"
    end
    MenuState(
        wad, sound, game, false, "main", 0, 0, 8, 0,
        nothing, false, nothing,
        fill(LOADSAVEEMPTY, 6), menus,
    )
end

function ticker(menu::MenuState)
    menu.active || return false
    menu.skull_tics -= 1
    if menu.skull_tics <= 0
        menu.which_skull = 1 - menu.which_skull
        menu.skull_tics = 8
        return true
    end
    false
end

function start(menu::MenuState)
    menu.active && return
    menu.active = true
    menu.screen = "main"
    menu.item_on = menu.menus["main"].last_on
    menu.message = nothing
    play(menu.sound, "swtchn")
end

function refresh_saves!(menu::MenuState)
    menu.game.slot_desc === nothing && return
    for i in 0:5
        menu.save_strings[i + 1] = menu.game.slot_desc(menu.game, i)
    end
    nothing
end

function clear(menu::MenuState)
    menu.active = false
    menu.message = nothing
end

function goto_menu(menu::MenuState, name::String)
    menu.menus[menu.screen].last_on = menu.item_on
    menu.screen = name
    menu.item_on = menu.menus[name].last_on
end

function do_action(menu::MenuState, action::String, choice::Int)
    game = menu.game
    if action == "newgame"
        if check_num_for_name(menu.wad, "MAP01") >= 0 || !has_episodes(menu.wad)
            menu.epi = 0
            goto_menu(menu, "skill")
        else
            goto_menu(menu, "episode")
        end
    elseif action == "options"
        goto_menu(menu, "options")
    elseif action == "loadgame"
        menu.message = nothing
        refresh_saves!(menu)
        goto_menu(menu, "load")
        play(menu.sound, "swtchn")
    elseif action == "savegame"
        if game.gamestate != "view" || game.save_game === nothing
            play(menu.sound, "oof")
        else
            refresh_saves!(menu)
            goto_menu(menu, "save")
            play(menu.sound, "swtchn")
        end
    elseif action == "loadslot"
        if game.load_game !== nothing && game.load_game(game, choice)
            clear(menu)
            play(menu.sound, "swtchx")
        else
            play(menu.sound, "oof")
        end
    elseif action == "saveslot"
        name = (game.world !== nothing && hasproperty(game.world, :mapname)) ? game.world.mapname : "save"
        if game.save_game !== nothing && game.save_game(game, choice, name)
            refresh_saves!(menu)
            clear(menu)
            play(menu.sound, "swtchx")
        else
            play(menu.sound, "oof")
        end
    elseif action == "readthis"
        goto_menu(menu, "read1")
    elseif action == "read2"
        if has_lump(menu, "HELP1") && menu.screen == "read1"
            goto_menu(menu, "read2")
        else
            goto_menu(menu, "main")
        end
    elseif action == "finishread"
        goto_menu(menu, "main")
    elseif action == "quit"
        menu.message = "ARE YOU SURE YOU WANT TO QUIT?"
        menu.message_confirm = true
        menu.message_action = "quit"
    elseif action == "endgame"
        if game.gamestate == "title" || game.end_game === nothing
            play(menu.sound, "oof")
        else
            menu.message = "ARE YOU SURE YOU WANT TO END THE GAME?"
            menu.message_confirm = true
            menu.message_action = "endgame"
        end
    elseif action == "sound"
        goto_menu(menu, "sound")
    elseif action == "messages"
        game.show_messages = !game.show_messages
    elseif action == "detail"
        game.detail_level = game.detail_level == 0 ? 1 : 0
    elseif action == "scrnsize"
        if choice != 0
            game.screen_size < 8 && (game.screen_size += 1)
        elseif game.screen_size > 0
            game.screen_size -= 1
        end
    elseif action == "mousesens"
        if choice != 0
            game.mouse_sensitivity < 9 && (game.mouse_sensitivity += 1)
        elseif game.mouse_sensitivity > 0
            game.mouse_sensitivity -= 1
        end
    elseif action == "sfxvol"
        vol = menu.sound.sfx_volume
        menu.sound.sfx_volume = choice != 0 ? min(15, vol + 1) : max(0, vol - 1)
    elseif action == "musvol"
        vol = menu.sound.music_volume
        menu.sound.music_volume = choice != 0 ? min(15, vol + 1) : max(0, vol - 1)
    elseif action == "episode"
        if !has_lump(menu, "E2M1") && choice != 0
            menu.message = "ONLY AVAILABLE IN THE REGISTERED VERSION."
            menu.message_confirm = false
            menu.message_action = nothing
            goto_menu(menu, "read1")
            return
        end
        menu.epi = choice
        goto_menu(menu, "skill")
    elseif action == "skill"
        game.skill = choice
        game.episode = menu.epi + 1
        game.mapn = 1
        if game.start_level !== nothing
            game.start_level(game)
            clear(menu)
        else
            menu.message = "EPISODIO $(menu.epi + 1) SKILL $choice"
            menu.message_confirm = false
            menu.message_action = nothing
        end
    end
end

function responder(menu::MenuState, key::AbstractString)
    if menu.message !== nothing
        if menu.message_confirm
            if key == "y" || key == "return"
                action = menu.message_action
                menu.message = nothing
                if action == "quit"
                    menu.game.running = false
                elseif action == "endgame" && menu.game.end_game !== nothing
                    menu.game.end_game(menu.game)
                    clear(menu)
                end
                return true
            end
            if key == "n" || key == "escape"
                menu.message = nothing
                return true
            end
            return true
        end
        if key != ""
            menu.message = nothing
            return true
        end
    end
    if key == "f1"
        menu.active = true
        menu.message = nothing
        menu.menus["read1"].last_on = 0
        menu.screen = "read1"
        menu.item_on = 0
        play(menu.sound, "swtchn")
        return true
    end
    if !menu.active
        if key == "escape" || key == "return"
            start(menu)
            return true
        end
        return false
    end
    current = menu.menus[menu.screen]
    if key == "escape"
        current.last_on = menu.item_on
        clear(menu)
        play(menu.sound, "swtchx")
        return true
    end
    if key == "backspace"
        current.last_on = menu.item_on
        if current.prev !== nothing
            menu.screen = current.prev
            menu.item_on = menu.menus[menu.screen].last_on
        else
            clear(menu)
        end
        play(menu.sound, "swtchx")
        return true
    end
    if key == "down" || key == "up"
        n = length(current.items)
        delta = key == "down" ? 1 : -1
        while true
            menu.item_on = mod(menu.item_on + delta, n)
            play(menu.sound, "pstop")
            current.items[menu.item_on + 1].status != -1 && break
        end
        return true
    end
    if key == "left" || key == "right"
        it = current.items[menu.item_on + 1]
        if it.status == 2 && it.action != ""
            play(menu.sound, "stnmov")
            do_action(menu, it.action, key == "left" ? 0 : 1)
        end
        return true
    end
    if key == "return"
        it = current.items[menu.item_on + 1]
        if it.status != 0
            current.last_on = menu.item_on
            play(menu.sound, "pistol")
            choice = it.status == 2 ? 1 : menu.item_on
            do_action(menu, it.action, choice)
        end
        return true
    end
    true
end

function stcfn(ch::Char)
    "STCFN" * lpad(string(Int(ch)), 3, '0')
end

function write_text(menu::MenuState, fb::Vector{UInt8}, x::Int, y::Int, text::AbstractString)
    xx = x
    for ch in uppercase(text)
        if ch == ' '
            xx += 4
        else
            p = patch(menu, stcfn(ch))
            if p !== nothing
                draw_patch(fb, xx, y, p)
                pw, _, _, _ = patch_size(p)
                xx += max(4, pw)
            else
                xx += 8
            end
        end
    end
    xx
end

function draw_thermo(menu::MenuState, fb::Vector{UInt8}, x::Int, y::Int, width::Int, dot::Int)
    left = patch(menu, "M_THERML")
    mid = patch(menu, "M_THERMM")
    right = patch(menu, "M_THERMR")
    knob = patch(menu, "M_THERMO")
    xx = x
    if left !== nothing
        draw_patch(fb, xx, y, left)
    end
    xx += 8
    for _ in 1:width
        if mid !== nothing
            draw_patch(fb, xx, y, mid)
        end
        xx += 8
    end
    if right !== nothing
        draw_patch(fb, xx, y, right)
    end
    if knob !== nothing
        at = min(width - 1, max(0, dot))
        draw_patch(fb, x + 8 + at * 8, y, knob)
    end
end

function draw_message(menu::MenuState, fb::Vector{UInt8})
    text = something(menu.message, "")
    menu.message_confirm && (text *= "  (Y/N)")
    x, y = 10, 80
    for ch in text
        if ch == ' '
            x += 8
        else
            p = patch(menu, stcfn(ch))
            if p !== nothing
                draw_patch(fb, x, y, p)
                pw, _, _, _ = patch_size(p)
                x += max(4, pw)
            else
                x += 8
            end
        end
        if x > 300
            x = 10
            y += 10
        end
    end
end

function draw_slots(menu::MenuState, fb::Vector{UInt8}, current::MenuDef)
    for i in 0:5
        y = current.y + LINEHEIGHT * i
        write_text(menu, fb, current.x, y, menu.save_strings[i + 1])
    end
end

function draw(menu::MenuState, fb::Vector{UInt8})
    menu.active || return
    if menu.message !== nothing
        draw_message(menu, fb)
        return
    end
    current = menu.menus[menu.screen]
    if current.routine == "main"
        p = patch(menu, "M_DOOM")
        p !== nothing && draw_patch(fb, 94, 2, p)
    elseif current.routine == "skill"
        p = patch(menu, "M_NEWG")
        p !== nothing && draw_patch(fb, 96, 14, p)
        p = patch(menu, "M_SKILL")
        p !== nothing && draw_patch(fb, 54, 38, p)
    elseif current.routine == "episode"
        p = patch(menu, "M_EPISOD")
        p !== nothing && draw_patch(fb, 54, 38, p)
    elseif current.routine == "options"
        p = patch(menu, "M_OPTTTL")
        p !== nothing && draw_patch(fb, 108, 15, p)
        msg = menu.game.show_messages ? "M_MSGON" : "M_MSGOFF"
        p = patch(menu, msg)
        p !== nothing && draw_patch(fb, current.x + 120, current.y + LINEHEIGHT, p)
        det = menu.game.detail_level == 0 ? "M_GDHIGH" : "M_GDLOW"
        p = patch(menu, det)
        p !== nothing && draw_patch(fb, current.x + 175, current.y + LINEHEIGHT * 2, p)
    elseif current.routine == "sound"
        p = patch(menu, "M_SVOL")
        p !== nothing && draw_patch(fb, 60, 38, p)
    elseif current.routine == "read1"
        lump = "CREDIT"
        if has_lump(menu, "HELP2")
            lump = "HELP2"
        elseif has_lump(menu, "HELP1")
            lump = "HELP1"
        elseif has_lump(menu, "HELP")
            lump = "HELP"
        end
        p = patch(menu, lump)
        p !== nothing && draw_patch(fb, 0, 0, p)
    elseif current.routine == "read2"
        p = patch(menu, "HELP1")
        p === nothing && (p = patch(menu, "CREDIT"))
        p !== nothing && draw_patch(fb, 0, 0, p)
    elseif current.routine == "load"
        p = patch(menu, "M_LOADG")
        p !== nothing && draw_patch(fb, 72, 28, p)
        draw_slots(menu, fb, current)
    elseif current.routine == "save"
        p = patch(menu, "M_SAVEG")
        p !== nothing && draw_patch(fb, 72, 28, p)
        draw_slots(menu, fb, current)
    end
    if current.routine != "read1" && current.routine != "read2" && current.routine != "load" && current.routine != "save"
        y = current.y
        for it in current.items
            if it.name != ""
                p = patch(menu, it.name)
                p !== nothing && draw_patch(fb, current.x, y, p)
            end
            y += LINEHEIGHT
        end
    end
    if current.routine == "options"
        draw_thermo(menu, fb, current.x, current.y + LINEHEIGHT * 4, 9, menu.game.screen_size)
        draw_thermo(menu, fb, current.x, current.y + LINEHEIGHT * 6, 10, menu.game.mouse_sensitivity)
    elseif current.routine == "sound"
        draw_thermo(menu, fb, current.x, current.y + LINEHEIGHT, 16, menu.sound.sfx_volume)
        draw_thermo(menu, fb, current.x, current.y + LINEHEIGHT * 3, 16, menu.sound.music_volume)
    end
    skull = menu.which_skull == 0 ? "M_SKULL1" : "M_SKULL2"
    p = patch(menu, skull)
    if p !== nothing && current.routine != "read1" && current.routine != "read2"
        draw_patch(fb, current.x + SKULLXOFF, current.y - 5 + menu.item_on * LINEHEIGHT, p)
    end
    nothing
end

end

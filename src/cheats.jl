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
# Cheats de st_stuff. Letras minusculas, um caractere por tecla.

module Cheats

using ..Compat
using ..Wad
using ..Player
using ..Snd

const CF_GODMODE = Player.CF_GODMODE
const CF_NOCLIP = Player.CF_NOCLIP
const MF_NOCLIP = Player.MF_NOCLIP
const WP_FIST = Player.WP_FIST
const WP_CHAINSAW = Player.WP_CHAINSAW

export new_cheats, feed!

mutable struct Seq
    action::String
    sequence::String
    param_chars::Int
    chars_read::Int
    param_buf::String
end

mutable struct CheatBox
    seqs::Vector{Seq}
end

function seq(action, text, params=0)
    Seq(action, text, params, 0, "")
end

function new_cheats()
    CheatBox([
        seq("god", "iddqd"),
        seq("kfa", "idkfa"),
        seq("fa", "idfa"),
        seq("noclip2", "idclip"),
        seq("noclip", "idspispopd"),
        seq("iddt", "iddt"),
        seq("beholdv", "idbeholdv"),
        seq("beholds", "idbeholds"),
        seq("beholdi", "idbeholdi"),
        seq("beholdr", "idbeholdr"),
        seq("beholda", "idbeholda"),
        seq("beholdl", "idbeholdl"),
        seq("behold", "idbehold"),
        seq("choppers", "idchoppers"),
        seq("mypos", "idmypos"),
        seq("clev", "idclev", 2),
        seq("mus", "idmus", 2),
    ])
end

function feed_one!(self::Seq, ch::Char)
    text = self.sequence
    n = length(text)
    n == 0 && return nothing
    if self.chars_read < n
        if ch == text[self.chars_read + 1]
            self.chars_read += 1
        elseif ch == text[1]
            self.chars_read = 1
        else
            self.chars_read = 0
        end
        self.chars_read < n && return nothing
        if self.param_chars <= 0
            self.chars_read = 0
            return ""
        end
        return nothing
    end
    if length(self.param_buf) < self.param_chars
        self.param_buf *= ch
    end
    if length(self.param_buf) >= self.param_chars
        buf = self.param_buf
        self.chars_read = 0
        self.param_buf = ""
        return buf
    end
    nothing
end

commercial(game) = check_num_for_name(game.wad, "MAP01") >= 0

function cheat_ammo!(player, keys)
    player.armorpoints = 200
    player.armortype = 2
    for i in 1:9
        player.weaponowned[i] = true
    end
    player.maxammo = [200, 50, 300, 50]
    for i in 1:4
        player.ammo[i] = player.maxammo[i]
    end
    keys && (player.cards = fill(true, 6))
    set_message(player, keys ? "Very Happy Ammo Added" : "Ammo Added")
end

const BEHOLD = Dict('v' => 0, 's' => 1, 'i' => 2, 'r' => 3, 'a' => 4, 'l' => 5)

function cheat_behold!(player, pw)
    pw < 0 && return
    if player.powers[pw + 1] == 0
        give_power(player, pw)
        if pw == 1 && player.readyweapon != WP_FIST
            player.pendingweapon = WP_FIST
        end
    elseif pw == 1
        player.powers[pw + 1] = 0
    else
        player.powers[pw + 1] = 1
    end
    set_message(player, "Power-up Toggled")
end

function do_cheat!(game, action, param)
    p = game.player
    p === nothing && return
    if action == "god"
        p.cheats = Int(bxor(p.cheats, CF_GODMODE))
        if Int(band(p.cheats, CF_GODMODE)) != 0
            p.health = 100
            p.mo !== nothing && (p.mo.health = 100)
            set_message(p, "Degreelessness Mode On")
        else
            set_message(p, "Degreelessness Mode Off")
        end
    elseif action == "kfa"
        cheat_ammo!(p, true)
    elseif action == "fa"
        cheat_ammo!(p, false)
    elseif action == "noclip" || action == "noclip2"
        p.cheats = Int(bxor(p.cheats, CF_NOCLIP))
        if p.mo !== nothing
            if Int(band(p.cheats, CF_NOCLIP)) != 0
                p.mo.flags = Int(bor(p.mo.flags, MF_NOCLIP))
            else
                p.mo.flags = Int(band(p.mo.flags, bnot(MF_NOCLIP)))
            end
        end
        set_message(p, Int(band(p.cheats, CF_NOCLIP)) != 0 ? "No Clipping Mode ON" : "No Clipping Mode OFF")
    elseif action == "iddt"
        am = game.automap
        if am !== nothing && am.active
            am.cheating = mod(am.cheating + 1, 3)
        end
    elseif action == "behold"
        set_message(p, "invin visis rad allmap lite amp")
    elseif startswith(action, "behold") && length(action) == 7
        pw = get(BEHOLD, action[7], nothing)
        pw !== nothing && cheat_behold!(p, pw)
    elseif action == "choppers"
        p.weaponowned[WP_CHAINSAW + 1] = true
        p.pendingweapon = WP_CHAINSAW
        p.powers[1] = 1
        set_message(p, "... doesn't suck - GM")
    elseif action == "mypos"
        mo = p.mo
        if mo !== nothing
            set_message(p, "ang=0x$(string(Int(as_u32(mo.angle)), base=16));x,y=(0x$(string(Int(as_u32(mo.x)), base=16)),0x$(string(Int(as_u32(mo.y)), base=16)))")
        end
    elseif action == "clev"
        (length(param) < 2 || !occursin(r"^\d\d$", param)) && return
        a = parse(Int, param[1:1])
        b = parse(Int, param[2:2])
        if commercial(game)
            episode = 1
            mapn = a * 10 + b
            lump = "MAP" * lpad(string(mapn), 2, '0')
        else
            episode = a
            mapn = b
            lump = "E$(episode)M$(mapn)"
        end
        (episode < 1 || mapn < 1 || check_num_for_name(game.wad, lump) < 0) && return
        set_message(p, "Changing Level...")
        game.episode = episode
        game.mapn = mapn
        game.start_level !== nothing && game.start_level(game)
    elseif action == "mus"
        (length(param) < 2 || !occursin(r"^\d\d$", param)) && return
        a = parse(Int, param[1:1])
        b = parse(Int, param[2:2])
        name = ""
        if commercial(game)
            mapn = a * 10 + b
            if mapn < 1 || mapn > length(DOOM2_MUSIC)
                set_message(p, "IMPOSSIBLE SELECTION")
                return
            end
            name = DOOM2_MUSIC[mapn]
        else
            if a < 1 || b < 1 || b > 9
                set_message(p, "IMPOSSIBLE SELECTION")
                return
            end
            name = "e$(a)m$(b)"
        end
        if game.sound === nothing || !has_music(game.sound, name)
            set_message(p, "IMPOSSIBLE SELECTION")
            return
        end
        change_music!(game.sound, name, true)
        set_message(p, "Music Change")
    end
    nothing
end

function feed!(self::CheatBox, ch, game)
    (game.nocheats || game.gamestate != "view" || game.player === nothing) && return
    (ch === nothing || length(string(ch)) != 1) && return
    code = Int(only(string(ch)))
    letter = (97 <= code <= 122) || (48 <= code <= 57)
    letter || return
    nightmare = game.skill == 4
    for cheat in self.seqs
        param = feed_one!(cheat, Char(code))
        if param !== nothing && !(nightmare && cheat.action != "clev" && cheat.action != "iddt")
            do_cheat!(game, cheat.action, param)
        end
    end
    nothing
end

end

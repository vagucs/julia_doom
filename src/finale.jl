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
# Texto de fim de episodio, arte, coelho e elenco.

module Finale

using ..Info
using ..Snd
using ..Sprites
using ..VVideo
using ..Wad

export commercial_map, new_finale, ticker!, responder!, draw_finale!

const TEXTSPEED = 3
const TEXTWAIT = 250
const STAGE_TEXT = 0
const STAGE_ART = 1
const STAGE_CAST = 2
const HU_FONTSTART = Int('!')
const HU_FONTEND = Int('_')
const SCREENWIDTH = 320
const SCREENHEIGHT = 200

const E1TEXT = "Once you beat the big badasses and\nclean out the moon base you're supposed\nto win, aren't you? Aren't you? Where's\nyour fat reward and ticket home? What\nthe hell is this? It's not supposed to\nend this way!\n\nIt stinks like rotten meat, but looks\nlike the lost Deimos base.  Looks like\nyou're stuck on The Shores of Hell.\nThe only way out is through.\n\nTo continue the DOOM experience, play\nThe Shores of Hell and its amazing\nsequel, Inferno!\n"
const E2TEXT = "You've done it! The hideous cyber-\ndemon lord that ruled the lost Deimos\nmoon base has been slain and you\nare triumphant! But ... where are\nyou? You clamber to the edge of the\nmoon and look down to see the awful\ntruth.\n\nDeimos floats above Hell itself!\nYou've never heard of anyone escaping\nfrom Hell, but you'll make the bastards\nsorry they ever heard of you! Quickly,\nyou rappel down to  the surface of\nHell.\n\nNow, it's on to the final chapter of\nDOOM! -- Inferno.\n"
const E3TEXT = "The loathsome spiderdemon that\nmasterminded the invasion of the moon\nbases and caused so much death has had\nits ass kicked for all time.\n\nA hidden doorway opens and you enter.\nYou've proven too tough for Hell to\ncontain, and now Hell at last plays\nfair -- for you emerge from the door\nto see the green fields of Earth!\nHome at last.\n\nYou wonder what's been happening on\nEarth while you were battling evil\nunleashed. It's good that no Hell-\nspawn could have come through that\ndoor with you ...\n"
const E4TEXT = "the spider mastermind must have sent forth\nits legions of hellspawn before your\nfinal confrontation with that terrible\nbeast from hell.  but you stepped forward\nand brought forth eternal damnation and\nsuffering upon the horde as a true hero\nwould in the face of something so evil.\n\nbesides, someone was gonna pay for what\nhappened to daisy, your pet rabbit.\n\nbut now, you see spread before you more\npotential pain and gibbitude as a nation\nof demons run amok among our cities.\n\nnext stop, hell on earth!"
const C1TEXT = "YOU HAVE ENTERED DEEPLY INTO THE INFESTED\nSTARPORT. BUT SOMETHING IS WRONG. THE\nMONSTERS HAVE BROUGHT THEIR OWN REALITY\nWITH THEM, AND THE STARPORT'S TECHNOLOGY\nIS BEING SUBVERTED BY THEIR PRESENCE.\n\nAHEAD, YOU SEE AN OUTPOST OF HELL, A\nFORTIFIED ZONE. IF YOU CAN GET PAST IT,\nYOU CAN PENETRATE INTO THE HAUNTED HEART\nOF THE STARBASE AND FIND THE CONTROLLING\nSWITCH WHICH HOLDS EARTH'S POPULATION\nHOSTAGE."

const TEXTS = Dict(1 => E1TEXT, 2 => E2TEXT, 3 => E3TEXT, 4 => E4TEXT)
const FLATS = Dict(1 => "FLOOR4_8", 2 => "SFLR6_1", 3 => "MFLR8_4", 4 => "MFLR8_3")
const D2_FLAT = Dict(6 => "SLIME16", 11 => "RROCK14", 20 => "RROCK07", 30 => "RROCK17", 15 => "RROCK13", 31 => "RROCK19")
const CASTORDER = [
    ("ZOMBIEMAN", MT_POSSESSED), ("SHOTGUN GUY", MT_SHOTGUY), ("HEAVY WEAPON DUDE", MT_CHAINGUY),
    ("IMP", MT_TROOP), ("DEMON", MT_SERGEANT), ("LOST SOUL", MT_SKULL), ("CACODEMON", MT_HEAD),
    ("HELL KNIGHT", MT_KNIGHT), ("BARON OF HELL", MT_BRUISER), ("ARACHNOTRON", MT_BABY),
    ("PAIN ELEMENTAL", MT_PAIN), ("REVENANT", MT_UNDEAD), ("MANCUBUS", MT_FATSO),
    ("ARCH-VILE", MT_VILE), ("THE SPIDER MASTERMIND", MT_SPIDER), ("THE CYBERDEMON", MT_CYBORG),
    ("OUR HERO", MT_PLAYER),
]
const CAST_SFX = Dict(
    S_PLAY_ATK1 => "dshtgn", S_POSS_ATK2 => "pistol", S_SPOS_ATK2 => "shotgn", S_VILE_ATK2 => "vilatk",
    S_SKEL_FIST2 => "skeswg", S_SKEL_FIST4 => "skepch", S_SKEL_MISS2 => "skeatk",
    S_FATT_ATK8 => "firsht", S_FATT_ATK5 => "firsht", S_FATT_ATK2 => "firsht",
    S_CPOS_ATK2 => "shotgn", S_CPOS_ATK3 => "shotgn", S_CPOS_ATK4 => "shotgn",
    S_TROO_ATK3 => "claw", S_SARG_ATK2 => "sgtatk", S_BOSS_ATK2 => "firsht", S_BOS2_ATK2 => "firsht",
    S_HEAD_ATK2 => "firsht", S_SKULL_ATK2 => "sklatk", S_SPID_ATK2 => "shotgn", S_SPID_ATK3 => "shotgn",
    S_BSPI_ATK2 => "plasma", S_CYBER_ATK2 => "rlaunc", S_CYBER_ATK4 => "rlaunc", S_CYBER_ATK6 => "rlaunc",
)

mutable struct Fin
    game::Any
    stage::Int
    count::Int
    done::Bool
    action::String
    commercial::Bool
    text::String
    flat::String
    flat_lump::Any
    art::Any
    pfub1::Any
    pfub2::Any
    bossback::Any
    last_bunny::Int
    castnum::Int
    caststate::Int
    casttics::Int
    castdeath::Bool
    castframes::Int
    castonmelee::Int
    castattacking::Bool
end

function commercial_map(mapn, secret)
    mapn == 6 || mapn == 11 || mapn == 20 || mapn == 30 || (secret && (mapn == 15 || mapn == 31))
end

function lump(wadfile, name)
    n = check_num_for_name(wadfile, name)
    n < 0 && return nothing
    cache_lump_num(wadfile, n)
end

function play_music(game, name, looping)
    snd = game.sound
    snd === nothing && return
    if snd isa Sound
        change_music!(snd, name, looping)
    elseif hasproperty(snd, :change_music)
        snd.change_music(name, looping)
    end
    nothing
end

function play_sfx(game, name)
    snd = game.sound
    snd === nothing && return
    if snd isa Sound
        play(snd, name)
    elseif hasproperty(snd, :play)
        snd.play(name)
    end
    nothing
end

function new_finale(game)
    commercial = check_num_for_name(game.wad, "MAP01") >= 0
    text, flat = E1TEXT, "FLOOR4_8"
    if commercial
        flat = get(D2_FLAT, game.mapn, "SLIME16")
        text = C1TEXT
        play_music(game, "read_m", true)
    else
        text = get(TEXTS, game.episode, E1TEXT)
        flat = get(FLATS, game.episode, "FLOOR4_8")
        play_music(game, "victor", true)
    end
    art_name = "HELP2"
    if commercial
        art_name = check_num_for_name(game.wad, "CREDIT") >= 0 ? "CREDIT" : "HELP2"
    elseif game.episode == 2
        art_name = "VICTORY2"
    elseif game.episode == 4
        art_name = "ENDPIC"
    elseif check_num_for_name(game.wad, "CREDIT") >= 0
        art_name = "CREDIT"
    end
    self = Fin(
        game, STAGE_TEXT, 0, false, "", commercial, text, flat,
        lump(game.wad, flat), lump(game.wad, art_name),
        nothing, nothing, lump(game.wad, "BOSSBACK"),
        -1, 0, S_NULL, 0, false, 0, 0, false,
    )
    self.art === nothing && (self.art = lump(game.wad, "HELP1"))
    if game.episode == 3 && !commercial
        self.pfub1 = lump(game.wad, "PFUB1")
        self.pfub2 = lump(game.wad, "PFUB2")
    end
    self
end

function want_skip(self)
    game = self.game
    if hasproperty(game, :menu) && game.menu !== nothing && game.menu.active
        return false
    end
    if hasproperty(game, :mouse_fire) && game.mouse_fire
        return true
    end
    held = hasproperty(game, :held) ? game.held : nothing
    held === nothing && return false
    get(held, "ctrl", false) || get(held, "space", false) || get(held, "return", false) || get(held, "e", false)
end

cast_info(self) = info_at(CASTORDER[self.castnum + 1][2])

function stop_attack!(self)
    self.castattacking = false
    self.castframes = 0
    self.caststate = cast_info(self).seestate
end

function cast_ticker!(self)
    self.casttics -= 1
    self.casttics > 0 && return
    st = state_at(self.caststate)
    if st.tics == -1 || st.nxt == S_NULL
        self.castnum += 1
        self.castdeath = false
        self.castnum >= length(CASTORDER) && (self.castnum = 0)
        self.caststate = cast_info(self).seestate
        self.castframes = 0
    else
        if self.caststate == S_PLAY_ATK1
            stop_attack!(self)
        else
            nxt = st.nxt
            self.caststate = nxt
            self.castframes += 1
            sfx = get(CAST_SFX, nxt, nothing)
            sfx !== nothing && play_sfx(self.game, sfx)
        end
    end
    if self.castframes == 12
        self.castattacking = true
        row = cast_info(self)
        self.caststate = self.castonmelee != 0 ? row.meleestate : row.missilestate
        self.castonmelee = self.castonmelee != 0 ? 0 : 1
        if self.caststate == S_NULL
            self.caststate = self.castonmelee != 0 ? row.meleestate : row.missilestate
        end
    end
    if self.castattacking && (self.castframes == 24 || self.caststate == cast_info(self).seestate)
        stop_attack!(self)
    end
    self.casttics = state_at(self.caststate).tics
    self.casttics == -1 && (self.casttics = 15)
end

function start_cast!(self)
    self.game.force_wipe = true
    self.castnum = 0
    self.caststate = info_at(CASTORDER[1][2]).seestate
    self.casttics = state_at(self.caststate).tics
    self.castdeath = false
    self.stage = STAGE_CAST
    self.castframes = 0
    self.castonmelee = 0
    self.castattacking = false
    play_music(self.game, "evil", true)
end

function ticker!(self)
    if self.commercial && self.stage == STAGE_TEXT && self.count > 50 && want_skip(self)
        if self.game.mapn == 30
            start_cast!(self)
        else
            self.action = "worlddone"
            self.done = true
            return
        end
    end
    self.count += 1
    if self.stage == STAGE_CAST
        cast_ticker!(self)
        return
    end
    self.commercial && return
    if self.stage == STAGE_TEXT
        if self.count > length(self.text) * TEXTSPEED + TEXTWAIT
            self.stage = STAGE_ART
            self.count = 0
            self.game.force_wipe = true
            self.game.episode == 3 && play_music(self.game, "bunny", true)
        end
    elseif self.stage == STAGE_ART
        skip_after = (self.pfub1 !== nothing && self.pfub2 !== nothing) ? 1130 : 10
        if want_skip(self) && self.count > skip_after
            self.done = true
            self.action = "title"
        end
    end
    nothing
end

function responder!(self)
    (self.stage != STAGE_CAST || self.castdeath) && return false
    want_skip(self) || return false
    row = cast_info(self)
    self.castdeath = true
    self.caststate = row.deathstate
    self.casttics = state_at(self.caststate).tics
    self.casttics == -1 && (self.casttics = 15)
    self.castframes = 0
    self.castattacking = false
    true
end

function font(self, code)
    (code < HU_FONTSTART || code > HU_FONTEND) && return nothing
    lump(self.game.wad, "STCFN" * lpad(string(code), 3, '0'))
end

function fill_flat!(self, fb)
    data = self.flat_lump
    if data === nothing || length(data) < 4096
        fill!(fb, 0x00)
        return
    end
    for y in 0:199
        row = (y % 64) * 64
        dest = y * SCREENWIDTH
        x = 0
        while x < SCREENWIDTH
            n = min(64, SCREENWIDTH - x)
            for i in 0:n - 1
                fb[dest + x + i + 1] = data[row + i + 1]
            end
            x += 64
        end
    end
end

function draw_text!(self, fb)
    fill_flat!(self, fb)
    nshow = fld(self.count, TEXTSPEED)
    cx, cy = 10, 10
    for (i, ch) in enumerate(self.text)
        i > nshow && break
        if ch == '\n'
            cx = 10
            cy += 11
        else
            code = Int(uppercase(ch))
            patch = (ch != ' ' && HU_FONTSTART <= code <= HU_FONTEND) ? font(self, code) : nothing
            if patch === nothing
                cx += 4
            else
                w = patch_size(patch)[1]
                cx + w > SCREENWIDTH && break
                draw_patch(fb, cx, cy, patch)
                cx += w
            end
        end
    end
end

function u32_at(data, off)
    off + 4 > length(data) && return 0
    Int(data[off + 1]) + Int(data[off + 2]) * 256 + Int(data[off + 3]) * 65536 + Int(data[off + 4]) * 16777216
end

function draw_patch_column!(fb, x, patch, column)
    column < 0 && return
    offset = u32_at(patch, 8 + column * 4)
    while offset < length(patch) && patch[offset + 1] != 0xff
        top = Int(patch[offset + 1])
        len = Int(patch[offset + 2])
        source = offset + 3
        for i in 0:len - 1
            top + i >= SCREENHEIGHT && break
            fb[(top + i) * SCREENWIDTH + x + 1] = patch[source + i + 1]
        end
        offset += len + 4
    end
end

function draw_bunny!(self, fb)
    fill!(fb, 0x00)
    scroll = 320 - fld(self.count - 230, 2)
    scroll < 0 && (scroll = 0)
    scroll > 320 && (scroll = 320)
    for x in 0:SCREENWIDTH - 1
        column = x + scroll
        if column < 320
            self.pfub2 !== nothing && draw_patch_column!(fb, x, self.pfub2, column)
        else
            self.pfub1 !== nothing && draw_patch_column!(fb, x, self.pfub1, column - 320)
        end
    end
    self.count < 1130 && return
    stage = 0
    if self.count >= 1180
        stage = min(6, fld(self.count - 1180, 5))
    end
    if stage > self.last_bunny
        play_sfx(self.game, "pistol")
        self.last_bunny = stage
    end
    patch = lump(self.game.wad, "END$stage")
    patch !== nothing && draw_patch(fb, fld(320 - 104, 2), fld(200 - 64, 2), patch)
end

function text_width(self, text)
    width = 0
    for ch in text
        code = Int(uppercase(ch))
        if ch == ' ' || code < HU_FONTSTART || code > HU_FONTEND
            width += 4
        else
            patch = font(self, code)
            width += patch === nothing ? 4 : patch_size(patch)[1]
        end
    end
    width
end

function cast_print!(self, fb, text)
    cx = 160 - fld(text_width(self, text), 2)
    for ch in text
        code = Int(uppercase(ch))
        if ch == ' ' || code < HU_FONTSTART || code > HU_FONTEND
            cx += 4
        else
            patch = font(self, code)
            if patch === nothing
                cx += 4
            else
                w = patch_size(patch)[1]
                draw_patch(fb, cx, 180, patch)
                cx += w
            end
        end
    end
end

function draw_cast!(self, fb)
    fill!(fb, 0x00)
    self.bossback !== nothing && draw_patch(fb, 0, 0, self.bossback)
    cast_print!(self, fb, CASTORDER[self.castnum + 1][1])
    st = state_at(self.caststate)
    spr = spr_name(st.sprite)
    (self.game.res === nothing || spr == "") && return
    frame = st.frame % 32768
    got = lookup(self.game.res, spr, 0, 0, frame)
    got === nothing && return
    lumpnum, flip = got
    lumpnum === nothing && return
    draw_patch(fb, 160, 170, cache_lump_num(self.game.wad, lumpnum); flipped=flip)
end

function draw_finale!(self, fb)
    if self.stage == STAGE_CAST
        draw_cast!(self, fb)
    elseif self.stage == STAGE_ART
        if self.game.episode == 3 && self.pfub1 !== nothing && self.pfub2 !== nothing
            draw_bunny!(self, fb)
        elseif self.art !== nothing
            fill!(fb, 0x00)
            draw_patch(fb, 0, 0, self.art)
        end
    else
        draw_text!(self, fb)
    end
    nothing
end

end

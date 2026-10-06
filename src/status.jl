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
# Barra de status. Vida, municao, armas, chaves e o rosto.

module Status

using ..Compat
using ..Wad
using ..VVideo
using ..Collision

export new_status, reset!, ticker!, draw_status!, draw_text!, text_width

const ST_AMMOX, ST_AMMOY = 44, 171
const ST_HEALTHX, ST_HEALTHY = 90, 171
const ST_ARMORX, ST_ARMORY = 221, 171
const ST_FACESX, ST_FACESY = 143, 168
const ST_ARMSX, ST_ARMSY = 111, 172
const ST_ARMSXSPACE, ST_ARMSYSPACE = 12, 10
const ST_KEY0X, ST_KEY0Y = 239, 171
const ST_AMMO_POS = ((288, 173), (288, 179), (288, 191), (288, 185))
const ST_MAX_POS = ((314, 173), (314, 179), (314, 191), (314, 185))
const ST_NUMPAINFACES = 5
const ST_NUMSTRAIGHTFACES = 3
const ST_NUMTURNFACES = 2
const ST_FACESTRIDE = 8
const ST_TURNOFFSET = 3
const ST_OUCHOFFSET = 5
const ST_EVILGRINOFFSET = 6
const ST_RAMPAGEOFFSET = 7
const ST_GODFACE = 40
const ST_DEADFACE = 41
const ST_EVILGRINCOUNT = 70
const ST_STRAIGHTFACECOUNT = 17
const ST_TURNCOUNT = 35
const ST_RAMPAGEDELAY = 70
const ST_MUCHPAIN = 20
const HU_FONTSTART = Int('!')
const ANG45 = 536870912
const ANG180 = 2147483648
const CF_GODMODE = 2
const PW_INVULNERABILITY = 0
const WP_PISTOL, WP_SHOTGUN, WP_CHAINGUN = 1, 2, 3
const WP_MISSILE, WP_PLASMA, WP_BFG, WP_SUPERSHOTGUN = 4, 5, 6, 8
const AM_CLIP, AM_SHELL, AM_CELL, AM_MISL = 0, 1, 2, 3

const WEAPON_AMMO = Dict(
    WP_PISTOL => AM_CLIP, WP_SHOTGUN => AM_SHELL, WP_SUPERSHOTGUN => AM_SHELL,
    WP_CHAINGUN => AM_CLIP, WP_MISSILE => AM_MISL, WP_PLASMA => AM_CELL, WP_BFG => AM_CELL,
)

mutable struct Bar
    wad::Any
    sbar::Any
    tallnum::Vector{Any}
    shortnum::Vector{Any}
    tallpercent::Any
    keys::Vector{Any}
    armsbg::Any
    arms_off::Vector{Any}
    fallback_face::Any
    faces::Vector{Any}
    font::Vector{Any}
    face_index::Int
    face_count::Int
    face_priority::Int
    old_health::Int
    pain_old_health::Int
    last_calc::Int
    last_attackdown::Int
    old_weapons_owned::Vector{Bool}
    rnd::Int
end

function lump(w, name)
    n = check_num_for_name(w, name)
    n < 0 && return nothing
    cache_lump_num(w, n)
end

function u32_lcg(rnd)
    lo = rnd % 65536
    hi = fld(rnd, 65536)
    prod = lo * 20077
    prod += (lo * 16838) * 65536
    prod += (hi * 20077) * 65536
    mod(prod + 12345, 4294967296)
end

function reset!(self, player)
    self.face_index = 0
    self.face_count = 0
    self.face_priority = 0
    self.old_health = -1
    self.pain_old_health = -1
    self.last_calc = 0
    self.last_attackdown = -1
    owned = fill(false, 9)
    if player !== nothing
        for i in 1:9
            owned[i] = player.weaponowned[i]
        end
    end
    self.old_weapons_owned = owned
    self.rnd = 1
    nothing
end

function new_status(w)
    tall = Any[]
    short = Any[]
    for i in 0:9
        push!(tall, lump(w, "STTNUM$i"))
        push!(short, lump(w, "STYSNUM$i"))
    end
    keys = Any[]
    for i in 0:5
        push!(keys, lump(w, "STKEYS$i"))
    end
    arms = Any[]
    for i in 2:7
        push!(arms, lump(w, "STGNUM$i"))
    end
    faces = Any[]
    for pain in 0:4
        for look in 0:2
            push!(faces, lump(w, "STFST$pain$look"))
        end
        push!(faces, lump(w, "STFTR$(pain)0"))
        push!(faces, lump(w, "STFTL$(pain)0"))
        push!(faces, lump(w, "STFOUCH$pain"))
        push!(faces, lump(w, "STFEVL$pain"))
        push!(faces, lump(w, "STFKILL$pain"))
    end
    push!(faces, lump(w, "STFGOD0"))
    push!(faces, lump(w, "STFDEAD0"))
    font = Any[]
    for ch in Int('!'):Int('_')
        push!(font, lump(w, "STCFN$(lpad(string(ch), 3, '0'))"))
    end
    bar = Bar(w, lump(w, "STBAR"), tall, short, lump(w, "STTPRCNT"), keys, lump(w, "STARMS"), arms, lump(w, "STFST00"), faces, font, 0, 0, 0, -1, -1, 0, -1, fill(false, 9), 1)
    reset!(bar, nothing)
    bar
end

face_patch(self, index) = (1 <= index + 1 <= length(self.faces) && self.faces[index + 1] !== nothing) ? self.faces[index + 1] : self.fallback_face

function calc_pain_offset(self, player)
    health = clamp(fld(player.health, 1), 0, 100)
    if health != self.pain_old_health
        self.last_calc = fld(ST_FACESTRIDE * ((100 - health) * ST_NUMPAINFACES), 101)
        self.pain_old_health = health
    end
    self.last_calc
end

function update_face!(self, player, st_random)
    if self.face_priority < 10 && player.health <= 0
        self.face_priority = 9
        self.face_index = ST_DEADFACE
        self.face_count = 1
    end
    if self.face_priority < 9 && player.bonuscount != 0
        grin = false
        for i in 0:8
            now = player.weaponowned[i + 1]
            if self.old_weapons_owned[i + 1] != now
                grin = true
                self.old_weapons_owned[i + 1] = now
            end
        end
        if grin
            self.face_priority = 8
            self.face_count = ST_EVILGRINCOUNT
            self.face_index = calc_pain_offset(self, player) + ST_EVILGRINOFFSET
        end
    end
    if self.face_priority < 8 && player.damagecount != 0 && player.attacker !== nothing && player.mo !== nothing && player.attacker !== player.mo
        self.face_priority = 7
        if player.health - self.old_health > ST_MUCHPAIN
            self.face_count = ST_TURNCOUNT
            self.face_index = calc_pain_offset(self, player) + ST_OUCHOFFSET
        else
            bad = angle_to(player.mo.x, player.mo.y, player.attacker.x, player.attacker.y)
            if as_u32(bad) > as_u32(player.mo.angle)
                diffang = as_u32(Int64(bad) - Int64(player.mo.angle))
                turn_right = diffang > as_u32(ANG180)
            else
                diffang = as_u32(Int64(player.mo.angle) - Int64(bad))
                turn_right = diffang <= as_u32(ANG180)
            end
            self.face_count = ST_TURNCOUNT
            self.face_index = calc_pain_offset(self, player)
            if diffang < as_u32(ANG45)
                self.face_index += ST_RAMPAGEOFFSET
            elseif turn_right
                self.face_index += ST_TURNOFFSET
            else
                self.face_index += ST_TURNOFFSET + 1
            end
        end
    end
    if self.face_priority < 7 && player.damagecount != 0
        if player.health - self.old_health > ST_MUCHPAIN
            self.face_priority = 7
            self.face_count = ST_TURNCOUNT
            self.face_index = calc_pain_offset(self, player) + ST_OUCHOFFSET
        else
            self.face_priority = 6
            self.face_count = ST_TURNCOUNT
            self.face_index = calc_pain_offset(self, player) + ST_RAMPAGEOFFSET
        end
    end
    if self.face_priority < 6
        if player.attackdown
            if self.last_attackdown == -1
                self.last_attackdown = ST_RAMPAGEDELAY
            else
                self.last_attackdown -= 1
                if self.last_attackdown == 0
                    self.face_priority = 5
                    self.face_index = calc_pain_offset(self, player) + ST_RAMPAGEOFFSET
                    self.face_count = 1
                    self.last_attackdown = 1
                end
            end
        else
            self.last_attackdown = -1
        end
    end
    inv = player.powers[PW_INVULNERABILITY + 1]
    if self.face_priority < 5 && (band(player.cheats, CF_GODMODE) != 0 || inv != 0)
        self.face_priority = 4
        self.face_index = ST_GODFACE
        self.face_count = 1
    end
    if self.face_count == 0
        self.face_index = calc_pain_offset(self, player) + (st_random % 3)
        self.face_count = ST_STRAIGHTFACECOUNT
        self.face_priority = 0
    end
    self.face_count -= 1
    nothing
end

function ticker!(self, player)
    player === nothing && return
    self.rnd = u32_lcg(self.rnd)
    st_random = fld(self.rnd, 65536) % 256
    update_face!(self, player, st_random)
    self.old_health = player.health
    nothing
end

function draw_digit(fb, x, y, n, font)
    n = clamp(n, 0, 9)
    patch = font[n + 1]
    patch !== nothing && draw_patch(fb, x, y, patch)
    nothing
end

function draw_num(fb, x, y, value, digits, font)
    w = 8
    font[1] !== nothing && (w = patch_size(font[1])[1])
    x -= w
    value = abs(fld(value, 1))
    for _ in 1:digits
        draw_digit(fb, x, y, value % 10, font)
        x -= w
        value = fld(value, 10)
        value == 0 && break
    end
end

function text_width(self, text)
    x = 0
    for ch in uppercase(text)
        idx = Int(ch) - HU_FONTSTART
        patch = 0 <= idx < length(self.font) ? self.font[idx + 1] : nothing
        x += patch !== nothing ? patch_size(patch)[1] : 4
    end
    x
end

function draw_text!(self, fb, x, y, text)
    for ch in uppercase(text)
        idx = Int(ch) - HU_FONTSTART
        patch = 0 <= idx < length(self.font) ? self.font[idx + 1] : nothing
        if patch !== nothing
            draw_patch(fb, x, y, patch)
            x += patch_size(patch)[1]
        else
            x += 4
        end
    end
    nothing
end

function draw_status!(self, fb, player, show_messages=true)
    self.sbar !== nothing && draw_patch(fb, 0, 168, self.sbar)
    self.armsbg !== nothing && draw_patch(fb, 104, 168, self.armsbg)
    at = get(WEAPON_AMMO, player.readyweapon, nothing)
    ammo = at === nothing ? 0 : player.ammo[at + 1]
    draw_num(fb, ST_AMMOX, ST_AMMOY, ammo, 3, self.tallnum)
    draw_num(fb, ST_HEALTHX, ST_HEALTHY, player.health, 3, self.tallnum)
    self.tallpercent !== nothing && draw_patch(fb, ST_HEALTHX, ST_HEALTHY, self.tallpercent)
    draw_num(fb, ST_ARMORX, ST_ARMORY, player.armorpoints, 3, self.tallnum)
    self.tallpercent !== nothing && draw_patch(fb, ST_ARMORX, ST_ARMORY, self.tallpercent)
    owned = [
        player.weaponowned[WP_SHOTGUN + 1] || player.weaponowned[WP_SUPERSHOTGUN + 1],
        player.weaponowned[WP_CHAINGUN + 1],
        player.weaponowned[WP_MISSILE + 1],
        player.weaponowned[WP_PLASMA + 1],
        player.weaponowned[WP_BFG + 1],
        false,
    ]
    for i in 0:5
        x = ST_ARMSX + (i % 3) * ST_ARMSXSPACE
        y = ST_ARMSY + fld(i, 3) * ST_ARMSYSPACE
        if owned[i + 1]
            draw_digit(fb, x, y, i + 2, self.shortnum)
        elseif self.arms_off[i + 1] !== nothing
            draw_patch(fb, x, y, self.arms_off[i + 1])
        end
    end
    face = face_patch(self, self.face_index)
    face !== nothing && draw_patch(fb, ST_FACESX, ST_FACESY, face)
    slots = ((0, 3, 0), (1, 4, 1), (2, 5, 2))
    for (card, skull, slot) in slots
        y = ST_KEY0Y + slot * 10
        idx = player.cards[skull + 1] ? skull : card
        if player.cards[card + 1] || player.cards[skull + 1]
            patch = self.keys[idx + 1]
            patch !== nothing && draw_patch(fb, ST_KEY0X, y, patch)
        end
    end
    order = (AM_CLIP, AM_SHELL, AM_CELL, AM_MISL)
    for i in 1:4
        am = order[i]
        draw_num(fb, ST_AMMO_POS[i][1], ST_AMMO_POS[i][2], player.ammo[am + 1], 3, self.shortnum)
        draw_num(fb, ST_MAX_POS[i][1], ST_MAX_POS[i][2], player.maxammo[am + 1], 3, self.shortnum)
    end
    if show_messages && player.message != ""
        draw_text!(self, fb, 0, 0, player.message)
    end
    nothing
end

end

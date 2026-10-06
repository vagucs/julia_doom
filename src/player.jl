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
# Jogador, gravidade e armas, a partir de player.py.
# A porta abre na fase 10.

module Player

using ..Compat
using ..Tables
using ..Collision
using ..Rng
using ..Sprites
using ..Wad

export spawn_player, think!, tick_fx!, damage_mobj, draw_weapon!
export build_ticcmd, empty_cmd, TicCmd, take_key!, apply_carry!, capture_carry
export set_message, give_power

const FRACUNIT = 65536
const ANG90 = 1073741824
const ANG180 = Int64(2147483648)
const FINEMASK = 8191
const FINEANGLES = 8192
const FRICTION = 59392
const GRAVITY = FRACUNIT
const STOPSPEED = 4096
const MAXMOVE = 30 * FRACUNIT
const MAXBOB = 1048576
const VIEWHEIGHT = 41 * FRACUNIT
const PLAYER_RADIUS = 16 * FRACUNIT
const PLAYER_HEIGHT = 56 * FRACUNIT
const MELEERANGE = 64 * FRACUNIT
const MISSILERANGE = 32 * 64 * FRACUNIT
const MF_SOLID = 2
const MF_SHOOTABLE = 4
const MF_DROPOFF = 1024
const MF_PICKUP = 2048
const MF_NOCLIP = 4096
const MF_NOGRAVITY = 512
const MF_MISSILE = 65536
const MF_CORPSE = 1048576
const MF_SKULLFLY = 16777216
const MF_SHADOW = 262144
const CF_NOCLIP = 1
const CF_GODMODE = 2
const CF_NOMOMENTUM = 4
const PST_LIVE = 0
const PST_DEAD = 1
const PST_REBORN = 2
const PW_INVULNERABILITY = 0
const PW_STRENGTH = 1
const PW_INVISIBILITY = 2
const PW_IRONFEET = 3
const PW_INFRARED = 5
const BT_ATTACK = 1
const BT_USE = 2
const BT_CHANGE = 4
const BT_WEAPONMASK = 56
const BT_WEAPONSHIFT = 3
const WP_FIST = 0
const WP_PISTOL = 1
const WP_SHOTGUN = 2
const WP_CHAINGUN = 3
const WP_MISSILE = 4
const WP_PLASMA = 5
const WP_BFG = 6
const WP_CHAINSAW = 7
const WP_SUPERSHOTGUN = 8
const WP_NOCHANGE = 10
const AM_CLIP = 0
const AM_SHELL = 1
const AM_CELL = 2
const AM_MISL = 3
const INVERSECOLORMAP = 32
const WEAPONTOP = 32 * FRACUNIT
const WEAPONBOTTOM = 128 * FRACUNIT
const LOWERSPEED = 6 * FRACUNIT
const RAISESPEED = 6 * FRACUNIT

const FORWARDMOVE = (25, 50)
const SIDEMOVE = (24, 40)
const ANGLETURN = (640, 1280, 320)

has(flags, bit) = band(flags, bit) != 0

mutable struct TicCmd
    forwardmove::Int
    sidemove::Int
    angleturn::Int
    buttons::Int
end

empty_cmd() = TicCmd(0, 0, 0, 0)

function trunc2(n)
    n = Int(as_i32(n))
    n < 0 ? -fld(-n, 2) : fld(n, 2)
end

const WEAPON_AMMO = Dict(
    WP_PISTOL => AM_CLIP,
    WP_SHOTGUN => AM_SHELL,
    WP_SUPERSHOTGUN => AM_SHELL,
    WP_CHAINGUN => AM_CLIP,
    WP_MISSILE => AM_MISL,
    WP_PLASMA => AM_CELL,
    WP_BFG => AM_CELL,
)

const WEAPON_PATCH = Dict(
    WP_FIST => "PUNGA0",
    WP_PISTOL => "PISGA0",
    WP_SHOTGUN => "SHTGA0",
    WP_CHAINGUN => "CHGGA0",
    WP_MISSILE => "MISGA0",
    WP_PLASMA => "PLSGA0",
    WP_BFG => "BFGGA0",
    WP_CHAINSAW => "SAWGC0",
    WP_SUPERSHOTGUN => "SHT2A0",
)

const WEAPON_FIRE_BODY = Dict(
    WP_FIST => "PUNGC0",
    WP_PISTOL => "PISGB0",
    WP_SHOTGUN => "SHTGA0",
    WP_CHAINGUN => "CHGGB0",
    WP_MISSILE => "MISGB0",
    WP_PLASMA => "PLSGA0",
    WP_BFG => "BFGGB0",
    WP_CHAINSAW => "SAWGA0",
    WP_SUPERSHOTGUN => "SHT2A0",
)

struct Atk
    body::String
    tics::Int
    shot::Bool
    flash::String
    flash_tics::Int
    light::Int
end

const WEAPON_ATK = Dict(
    WP_FIST => Atk[
        Atk("PUNGB0", 4, false, "", 0, 0),
        Atk("PUNGC0", 4, true, "", 0, 0),
        Atk("PUNGD0", 5, false, "", 0, 0),
        Atk("PUNGC0", 4, false, "", 0, 0),
        Atk("PUNGB0", 5, false, "", 0, 0),
    ],
    WP_PISTOL => Atk[
        Atk("PISGA0", 4, false, "", 0, 0),
        Atk("PISGB0", 6, true, "PISFA0", 7, 1),
        Atk("PISGC0", 4, false, "", 0, 0),
        Atk("PISGB0", 5, false, "", 0, 0),
    ],
    WP_SHOTGUN => Atk[
        Atk("SHTGA0", 3, false, "", 0, 0),
        Atk("SHTGA0", 7, true, "SHTFA0", 7, 1),
        Atk("SHTGB0", 5, false, "", 0, 0),
        Atk("SHTGC0", 5, false, "", 0, 0),
        Atk("SHTGD0", 4, false, "", 0, 0),
        Atk("SHTGC0", 5, false, "", 0, 0),
        Atk("SHTGB0", 5, false, "", 0, 0),
        Atk("SHTGA0", 3, false, "", 0, 0),
        Atk("SHTGA0", 7, false, "", 0, 0),
    ],
    WP_CHAINGUN => Atk[
        Atk("CHGGA0", 4, true, "CHGFA0", 5, 1),
        Atk("CHGGB0", 4, true, "CHGFB0", 5, 2),
    ],
    WP_MISSILE => Atk[
        Atk("MISGB0", 8, false, "MISFA0", 15, 1),
        Atk("MISGB0", 12, true, "", 0, 2),
    ],
    WP_PLASMA => Atk[
        Atk("PLSGA0", 3, true, "PLSFA0", 4, 1),
        Atk("PLSGB0", 20, false, "", 0, 0),
    ],
    WP_BFG => Atk[
        Atk("BFGGA0", 20, false, "", 0, 0),
        Atk("BFGGB0", 10, false, "BFGFA0", 17, 1),
        Atk("BFGGB0", 10, true, "", 0, 2),
        Atk("BFGGB0", 20, false, "", 0, 0),
    ],
    WP_CHAINSAW => Atk[
        Atk("SAWGA0", 4, true, "", 0, 0),
        Atk("SAWGB0", 4, true, "", 0, 0),
    ],
    WP_SUPERSHOTGUN => Atk[
        Atk("SHT2A0", 3, false, "", 0, 0),
        Atk("SHT2A0", 7, true, "SHT2I0", 9, 1),
        Atk("SHT2B0", 7, false, "", 0, 0),
        Atk("SHT2C0", 7, false, "", 0, 0),
        Atk("SHT2D0", 7, false, "", 0, 0),
        Atk("SHT2E0", 7, false, "", 0, 0),
        Atk("SHT2F0", 7, false, "", 0, 0),
        Atk("SHT2G0", 6, false, "", 0, 0),
        Atk("SHT2H0", 6, false, "", 0, 0),
        Atk("SHT2A0", 5, false, "", 0, 0),
    ],
)

struct Ready
    body::String
    tics::Int
    sfx::String
end

const WEAPON_READY = Dict(
    WP_CHAINSAW => Ready[
        Ready("SAWGC0", 4, "sawidl"),
        Ready("SAWGD0", 4, ""),
    ],
)

mutable struct DoomPlayer
    mo::Any
    cmd::TicCmd
    playerstate::Int
    viewz::Int
    viewheight::Int
    deltaviewheight::Int
    bob::Int
    health::Int
    armorpoints::Int
    armortype::Int
    ammo::Vector{Int}
    maxammo::Vector{Int}
    weaponowned::Vector{Bool}
    pendingweapon::Int
    readyweapon::Int
    cards::Vector{Bool}
    cheats::Int
    attackdown::Bool
    usedown::Bool
    damagecount::Int
    bonuscount::Int
    attacker::Any
    extralight::Int
    fixedcolormap::Int
    refire::Int
    killcount::Int
    itemcount::Int
    secretcount::Int
    psprite_sy::Int
    psprite_state::String
    psprite_tics::Int
    psprite_step::Int
    psprite_body::String
    psprite_flash::String
    flash_tics::Int
    powers::Vector{Int}
    message::String
    message_tics::Int
end

function damage_mobj(target, source, damage, inflictor=nothing)
    (target === nothing || target.alive == false || !has(target.flags, MF_SHOOTABLE)) && return
    if target.player !== nothing
        player = target.player
        if (has(player.cheats, CF_GODMODE) || player.powers[PW_INVULNERABILITY + 1] != 0) && damage < 1000
            return
        end
        saved = 0
        if player.armortype != 0
            div = player.armortype == 1 ? 3 : 2
            saved = fld(damage, div)
            if player.armorpoints <= saved
                saved = player.armorpoints
                player.armortype = 0
            end
            player.armorpoints -= saved
        end
        damage -= saved
        player.health -= damage
        target.health = player.health
        player.damagecount += damage
        player.damagecount > 100 && (player.damagecount = 100)
        player.attacker = source
        if player.health <= 0
            player.health = 0
            target.health = 0
            player.playerstate = PST_DEAD
            target.alive = false
            target.flags = Int(band(target.flags, bnot(MF_SOLID + MF_SHOOTABLE)))
        end
        return
    end
    target.health -= damage
    if target.health <= 0
        target.health = 0
        target.alive = false
        target.flags = Int(band(target.flags, bnot(MF_SOLID + MF_SHOOTABLE)))
    end
    nothing
end

function spawn_player(world, start, cheats=0)
    init_tables!()
    x = start.x * FRACUNIT
    y = start.y * FRACUNIT
    sub = point_in_subsector(world, x, y)
    flags = MF_SOLID + MF_SHOOTABLE + MF_PICKUP + MF_DROPOFF
    has(cheats, CF_NOCLIP) && (flags = Int(bor(flags, MF_NOCLIP)))
    mo = new_mobj(
        x=x, y=y, z=Int(sub.sector.floorheight),
        angle=as_u32(fld(start.angle, 45) * 536870912),
        radius=PLAYER_RADIUS, height=PLAYER_HEIGHT,
        floorz=Int(sub.sector.floorheight), ceilingz=Int(sub.sector.ceilingheight),
        flags=flags, health=100, sprite="PLAY", alive=true,
    )
    player = DoomPlayer(
        mo, empty_cmd(), PST_LIVE, mo.z + VIEWHEIGHT, VIEWHEIGHT, 0, 0,
        100, 0, 0, [50, 0, 0, 0], [200, 50, 300, 50],
        [true, true, false, false, false, false, false, false, false],
        WP_NOCHANGE, WP_PISTOL, fill(false, 6), cheats, false, false,
        0, 0, nothing, 0, 0, 0, 0, 0, 0,
        WEAPONBOTTOM, "up", 0, 0, "", "", 0, zeros(Int, 6), "", 0,
    )
    mo.player = player
    p_random()
    push!(world.mobjs, mo)
    set_thing_position!(world, mo)
    player
end

function thrust!(mo, angle, move)
    mo.momx += Int(fixed_mul(move, fine_cos(angle)))
    mo.momy += Int(fixed_mul(move, fine_sin(angle)))
    nothing
end

function calc_height!(player, leveltime)
    mo = player.mo
    player.bob = fld(Int(fixed_mul(mo.momx, mo.momx)) + Int(fixed_mul(mo.momy, mo.momy)), 4)
    player.bob > MAXBOB && (player.bob = MAXBOB)
    onground = mo.z <= mo.floorz
    if !onground
        player.viewz = mo.z + player.viewheight
        if player.viewz > mo.ceilingz - 4 * FRACUNIT
            player.viewz = mo.ceilingz - 4 * FRACUNIT
        end
        return
    end
    angle = Int(band(fld(FINEANGLES, 20) * leveltime, FINEMASK))
    bob = Int(fixed_mul(fld(player.bob, 2), sine_at(angle)))
    if player.playerstate == PST_LIVE
        player.viewheight += player.deltaviewheight
        if player.viewheight > VIEWHEIGHT
            player.viewheight = VIEWHEIGHT
            player.deltaviewheight = 0
        end
        if player.viewheight < fld(VIEWHEIGHT, 2)
            player.viewheight = fld(VIEWHEIGHT, 2)
            player.deltaviewheight <= 0 && (player.deltaviewheight = 1)
        end
        if player.deltaviewheight != 0
            player.deltaviewheight += fld(FRACUNIT, 4)
        end
    end
    player.viewz = mo.z + player.viewheight + bob
    if player.viewz > mo.ceilingz - 4 * FRACUNIT
        player.viewz = mo.ceilingz - 4 * FRACUNIT
    end
    nothing
end

function xy_movement!(world, mo, game)
    if mo.momx == 0 && mo.momy == 0
        if has(mo.flags, MF_SKULLFLY)
            mo.flags = Int(band(mo.flags, bnot(MF_SKULLFLY)))
            mo.momx = 0
            mo.momy = 0
            mo.momz = 0
        end
        return
    end
    mo.momx > MAXMOVE && (mo.momx = MAXMOVE)
    mo.momx < -MAXMOVE && (mo.momx = -MAXMOVE)
    mo.momy > MAXMOVE && (mo.momy = MAXMOVE)
    mo.momy < -MAXMOVE && (mo.momy = -MAXMOVE)
    xmove, ymove = mo.momx, mo.momy
    half = fld(MAXMOVE, 2)
    while xmove != 0 || ymove != 0
        if xmove > half || ymove > half
            ptryx = mo.x + trunc2(xmove)
            ptryy = mo.y + trunc2(ymove)
            xmove = trunc2(xmove)
            ymove = trunc2(ymove)
        else
            ptryx = mo.x + xmove
            ptryy = mo.y + ymove
            xmove, ymove = 0, 0
        end
        if has(mo.flags, MF_NOCLIP)
            unset_thing_position!(world, mo)
            mo.x = ptryx
            mo.y = ptryy
            set_thing_position!(world, mo)
        elseif try_move!(world, mo, ptryx, ptryy, game)
        elseif mo.player !== nothing
            slide_move!(world, mo, mo.momx, mo.momy, game)
        else
            mo.momx = 0
            mo.momy = 0
        end
    end
    player = mo.player
    if player !== nothing && has(player.cheats, CF_NOMOMENTUM)
        mo.momx = 0
        mo.momy = 0
        return
    end
    has(mo.flags, MF_MISSILE + MF_SKULLFLY) && return
    mo.z > mo.floorz && return
    if has(mo.flags, MF_CORPSE)
        lim = fld(FRACUNIT, 4)
        if mo.momx > lim || mo.momx < -lim || mo.momy > lim || mo.momy < -lim
            sec = point_in_subsector(world, mo.x, mo.y).sector
            mo.floorz != Int(sec.floorheight) && return
        end
    end
    cmd = player === nothing ? nothing : player.cmd
    idle = player === nothing || (cmd.forwardmove == 0 && cmd.sidemove == 0)
    if -STOPSPEED < mo.momx < STOPSPEED && -STOPSPEED < mo.momy < STOPSPEED && idle
        mo.momx = 0
        mo.momy = 0
    else
        mo.momx = Int(fixed_mul(mo.momx, FRICTION))
        mo.momy = Int(fixed_mul(mo.momy, FRICTION))
    end
    nothing
end

function z_movement!(mo, world, game)
    player = mo.player
    if player !== nothing && mo.z < mo.floorz
        player.viewheight -= mo.floorz - mo.z
        player.deltaviewheight = Int(shar(VIEWHEIGHT - player.viewheight, 3))
    end
    mo.z += mo.momz
    if mo.z <= mo.floorz
        if mo.momz < 0
            if player !== nothing && mo.momz < -GRAVITY * 8
                player.deltaviewheight = Int(shar(mo.momz, 3))
                if game !== nothing && game.start_sound !== nothing
                    game.start_sound("oof")
                end
            end
            mo.momz = 0
        end
        mo.z = mo.floorz
        if has(mo.flags, MF_SKULLFLY) && !has(mo.flags, MF_MISSILE)
            mo.momz = -mo.momz
        end
    elseif !has(mo.flags, MF_NOGRAVITY)
        if mo.momz == 0
            mo.momz = -GRAVITY * 2
        else
            mo.momz -= GRAVITY
        end
    end
    if mo.z + mo.height > mo.ceilingz
        if mo.momz > 0
            mo.momz = 0
        end
        mo.z = mo.ceilingz - mo.height
        has(mo.flags, MF_SKULLFLY) && (mo.momz = -mo.momz)
    end
    nothing
end

function special_sector!(world, player, game, leveltime)
    mo = player.mo
    mo === nothing && return
    sector = point_in_subsector(world, mo.x, mo.y).sector
    (mo.z != Int(sector.floorheight) || sector.special == 0) && return
    spec = sector.special
    if spec == 9
        player.secretcount += 1
        sector.special = 0
        return
    end
    if spec == 5 || spec == 7 || spec == 4 || spec == 16 || spec == 11
        player.powers[PW_IRONFEET + 1] != 0 && return
        band(leveltime, 31) != 0 && return
        if game !== nothing && game.damage_mobj !== nothing
            dmg = spec == 5 ? 10 : spec == 7 ? 5 : 20
            game.damage_mobj(mo, nothing, dmg)
        end
    end
    nothing
end

ammo_needed(weapon) = weapon == WP_BFG ? 40 : 1

function gun_shot!(player, game, accurate)
    mo = player.mo
    slope = bullet_slope(game.world, mo)
    damage = 5 * ((p_random() % 3) + 1)
    angle = mo.angle
    if !accurate
        angle = as_u32(Int64(angle) + Int64(p_random() - p_random()) * 262144)
    end
    line_attack!(game.world, mo, damage, game, MISSILERANGE, angle, slope)
end

function do_shot!(player, game, ammo_type)
    need = ammo_needed(player.readyweapon)
    if ammo_type !== nothing
        player.ammo[ammo_type + 1] < need && return
        player.ammo[ammo_type + 1] -= need
    end
    mo = player.mo
    weapon = player.readyweapon
    if mo !== nothing && (weapon == WP_MISSILE || weapon == WP_PLASMA || weapon == WP_BFG)
        weapon == WP_PLASMA && p_random()
        if game !== nothing && game.fire_missile !== nothing
            kind = weapon == WP_MISSILE ? "rocket" : weapon == WP_PLASMA ? "plasma" : "bfg"
            game.fire_missile(game.world, mo, kind)
            sfx = kind == "rocket" ? "rlaunc" : kind
            game.start_sound !== nothing && game.start_sound(sfx)
        end
        player.refire += 1
        player.attackdown = true
        if game !== nothing && game.noise_alert !== nothing
            game.noise_alert(game.world, mo, game)
        end
        return
    end
    if mo !== nothing && weapon == WP_FIST
        damage = ((p_random() % 10) + 1) * 2
        player.powers[PW_STRENGTH + 1] != 0 && (damage *= 10)
        angle = as_u32(Int64(mo.angle) + Int64(p_random() - p_random()) * 262144)
        hit = line_attack!(game.world, mo, damage, game, MELEERANGE, angle, nothing)
        if hit && game !== nothing && game.start_sound !== nothing
            game.start_sound("punch")
        end
    elseif mo !== nothing && weapon == WP_CHAINSAW
        damage = 2 * ((p_random() % 10) + 1)
        angle = as_u32(Int64(mo.angle) + Int64(p_random() - p_random()) * 262144)
        hit = line_attack!(game.world, mo, damage, game, MELEERANGE + 1, angle, nothing)
        if game !== nothing && game.start_sound !== nothing
            game.start_sound(hit ? "sawhit" : "sawful")
        end
    elseif mo !== nothing && weapon == WP_SHOTGUN
        if game !== nothing && game.start_sound !== nothing
            game.start_sound("shotgn")
        end
        for _ in 1:7
            gun_shot!(player, game, false)
        end
    elseif mo !== nothing && weapon == WP_SUPERSHOTGUN
        if game !== nothing && game.start_sound !== nothing
            game.start_sound("dshtgn")
        end
        slope = bullet_slope(game.world, mo)
        for _ in 1:20
            damage = 5 * ((p_random() % 3) + 1)
            angle = as_u32(Int64(mo.angle) + Int64(p_random() - p_random()) * 524288)
            pellet = slope + (p_random() - p_random()) * 32
            line_attack!(game.world, mo, damage, game, MISSILERANGE, angle, pellet)
        end
    elseif mo !== nothing
        if game !== nothing && game.start_sound !== nothing
            game.start_sound("pistol")
        end
        gun_shot!(player, game, player.refire == 0)
    end
    player.refire += 1
    player.attackdown = true
    if game !== nothing && mo !== nothing && game.noise_alert !== nothing
        game.noise_alert(game.world, mo, game)
    end
    nothing
end

function start_ready!(player, game)
    player.psprite_state = "ready"
    player.psprite_step = 0
    seq = get(WEAPON_READY, player.readyweapon, nothing)
    if seq === nothing
        player.psprite_body = get(WEAPON_PATCH, player.readyweapon, "PISGA0")
        player.psprite_tics = 0
        return
    end
    row = seq[1]
    player.psprite_body = row.body
    player.psprite_tics = row.tics
    if row.sfx != "" && game !== nothing && game.start_sound !== nothing
        game.start_sound(row.sfx)
    end
    nothing
end

function tick_ready!(player, game)
    seq = get(WEAPON_READY, player.readyweapon, nothing)
    if seq === nothing
        player.psprite_body = get(WEAPON_PATCH, player.readyweapon, "PISGA0")
        return
    end
    if player.psprite_tics > 0
        player.psprite_tics -= 1
        player.psprite_tics > 0 && return
        player.psprite_step = mod(player.psprite_step + 1, length(seq))
    end
    row = seq[player.psprite_step + 1]
    player.psprite_body = row.body
    player.psprite_tics = row.tics
    if row.sfx != "" && game !== nothing && game.start_sound !== nothing
        game.start_sound(row.sfx)
    end
    nothing
end

function enter_atk_step!(player, game, ammo_type, firing, can_fire)
    seq = get(WEAPON_ATK, player.readyweapon, WEAPON_ATK[WP_PISTOL])
    while true
        if player.psprite_step >= length(seq)
            if firing && can_fire && player.pendingweapon == WP_NOCHANGE
                player.psprite_step = 0
            else
                start_ready!(player, game)
                if !firing
                    player.attackdown = false
                    player.refire = 0
                end
                return
            end
        else
            row = seq[player.psprite_step + 1]
            player.psprite_body = row.body
            player.psprite_tics = row.tics
            if row.flash_tics != 0
                player.psprite_flash = row.flash
                player.flash_tics = row.flash_tics
            end
            row.light != 0 && (player.extralight = row.light)
            row.shot && do_shot!(player, game, ammo_type)
            row.tics > 0 && return
            player.psprite_step += 1
        end
    end
end

function lower_weapon!(player, game)
    player.psprite_state = "down"
    if player.psprite_body == ""
        player.psprite_body = get(WEAPON_PATCH, player.readyweapon, "PISGA0")
    end
    player.psprite_sy += LOWERSPEED
    player.psprite_sy < WEAPONBOTTOM && return
    player.psprite_sy = WEAPONBOTTOM
    (player.playerstate == PST_DEAD || player.health <= 0) && return
    if player.pendingweapon != WP_NOCHANGE
        player.readyweapon = player.pendingweapon
        player.pendingweapon = WP_NOCHANGE
    end
    if player.readyweapon == WP_CHAINSAW && game !== nothing && game.start_sound !== nothing
        game.start_sound("sawup")
    end
    player.psprite_state = "up"
    player.psprite_body = get(WEAPON_PATCH, player.readyweapon, "PISGA0")
    nothing
end

function raise_weapon!(player, game)
    player.psprite_sy -= RAISESPEED
    if player.psprite_body == ""
        player.psprite_body = get(WEAPON_PATCH, player.readyweapon, "PISGA0")
    end
    player.psprite_sy > WEAPONTOP && return
    player.psprite_sy = WEAPONTOP
    start_ready!(player, game)
    nothing
end

function weapon_think!(player, game)
    if player.playerstate == PST_DEAD || player.health <= 0
        lower_weapon!(player, game)
        return
    end
    cmd = player.cmd
    firing = band(cmd.buttons, BT_ATTACK) != 0
    ammo_type = get(WEAPON_AMMO, player.readyweapon, nothing)
    can_fire = true
    need = ammo_needed(player.readyweapon)
    if ammo_type !== nothing && player.ammo[ammo_type + 1] < need
        can_fire = player.readyweapon == WP_FIST || player.readyweapon == WP_CHAINSAW
        if !can_fire
            for w in (WP_PISTOL, WP_SHOTGUN, WP_CHAINGUN, WP_MISSILE, WP_PLASMA, WP_BFG, WP_FIST)
                at = get(WEAPON_AMMO, w, nothing)
                if player.weaponowned[w + 1] && (at === nothing || player.ammo[at + 1] >= ammo_needed(w))
                    player.pendingweapon = w
                    break
                end
            end
            ammo_type = get(WEAPON_AMMO, player.readyweapon, nothing)
            can_fire = ammo_type === nothing || player.ammo[ammo_type + 1] >= ammo_needed(player.readyweapon)
        end
    end
    if player.flash_tics > 0
        player.flash_tics -= 1
        if player.flash_tics <= 0
            player.psprite_flash = ""
            player.extralight = 0
        end
    end
    player.psprite_state == "fire" && (player.psprite_state = "atk")
    if player.psprite_state == "atk"
        firing && (player.attackdown = true)
        player.psprite_tics > 0 && (player.psprite_tics -= 1)
        player.psprite_tics > 0 && return
        player.psprite_step += 1
        enter_atk_step!(player, game, ammo_type, firing, can_fire)
        return
    end
    if player.pendingweapon != WP_NOCHANGE || player.psprite_state == "down"
        lower_weapon!(player, game)
        return
    end
    if player.psprite_state == "up"
        raise_weapon!(player, game)
        return
    end
    if firing && can_fire
        ready_gate = !player.attackdown || (player.readyweapon != WP_MISSILE && player.readyweapon != WP_BFG)
        if ready_gate
            player.psprite_state = "atk"
            player.psprite_step = 0
            player.psprite_sy = WEAPONTOP
            player.attackdown = true
            enter_atk_step!(player, game, ammo_type, firing, can_fire)
            return
        end
    end
    if player.psprite_state != "ready"
        start_ready!(player, game)
        return
    end
    tick_ready!(player, game)
    if !firing
        player.attackdown = false
        player.refire = 0
    end
    nothing
end

function death_think!(world, player, game, leveltime)
    mo = player.mo
    cmd = player.cmd
    if player.viewheight > 6 * FRACUNIT
        player.viewheight -= FRACUNIT
    end
    player.viewheight < 6 * FRACUNIT && (player.viewheight = 6 * FRACUNIT)
    player.deltaviewheight = 0
    xy_movement!(world, mo, game)
    z_movement!(mo, world, game)
    calc_height!(player, leveltime)
    if player.attacker !== nothing && player.attacker !== mo
        angle = angle_to(mo.x, mo.y, player.attacker.x, player.attacker.y)
        delta = as_u32(Int64(angle) - Int64(mo.angle))
        ang5 = fld(ANG90, 18)
        if delta < as_u32(ang5) || delta > as_u32(-ang5)
            mo.angle = angle
            player.damagecount != 0 && (player.damagecount -= 1)
        elseif delta < as_u32(ANG180)
            mo.angle = as_u32(Int64(mo.angle) + ang5)
        else
            mo.angle = as_u32(Int64(mo.angle) - ang5)
        end
    elseif player.damagecount != 0
        player.damagecount -= 1
    end
    weapon_think!(player, game)
    band(cmd.buttons, BT_USE) != 0 && (player.playerstate = PST_REBORN)
    nothing
end

function think!(world, player, game, leveltime)
    mo = player.mo
    cmd = player.cmd
    if player.playerstate == PST_DEAD
        death_think!(world, player, game, leveltime)
        return
    end
    mo.angle = as_u32(Int64(mo.angle) + Int64(cmd.angleturn) * 65536)
    onground = mo.z <= mo.floorz
    if cmd.forwardmove != 0 && onground
        thrust!(mo, mo.angle, cmd.forwardmove * 2048)
    end
    if cmd.sidemove != 0 && onground
        thrust!(mo, as_u32(Int64(mo.angle) - ANG90), cmd.sidemove * 2048)
    end
    xy_movement!(world, mo, game)
    z_movement!(mo, world, game)
    calc_height!(player, leveltime)
    special_sector!(world, player, game, leveltime)
    if band(cmd.buttons, BT_USE) != 0
        if !player.usedown
            use_lines!(world, player, game)
            player.usedown = true
        end
    else
        player.usedown = false
    end
    if band(cmd.buttons, BT_CHANGE) != 0
        neww = fld(Int(band(cmd.buttons, BT_WEAPONMASK)), 1 << BT_WEAPONSHIFT)
        if 0 <= neww <= WP_SUPERSHOTGUN && player.weaponowned[neww + 1] && neww != player.readyweapon
            player.pendingweapon = neww
        end
    end
    weapon_think!(player, game)
    if player.powers[PW_STRENGTH + 1] != 0
        player.powers[PW_STRENGTH + 1] += 1
    end
    for (pw, shadow) in ((PW_INVULNERABILITY, false), (PW_INVISIBILITY, true), (PW_INFRARED, false), (PW_IRONFEET, false))
        if player.powers[pw + 1] != 0
            player.powers[pw + 1] -= 1
            if shadow && player.powers[pw + 1] == 0
                mo.flags = Int(band(mo.flags, bnot(MF_SHADOW)))
            end
        end
    end
    inv = player.powers[PW_INVULNERABILITY + 1]
    ir = player.powers[PW_INFRARED + 1]
    if inv != 0
        player.fixedcolormap = (inv > 4 * 32 || band(inv, 8) != 0) ? INVERSECOLORMAP : 0
    elseif ir != 0
        player.fixedcolormap = (ir > 4 * 32 || band(ir, 8) != 0) ? 1 : 0
    else
        player.fixedcolormap = 0
    end
    player.damagecount != 0 && (player.damagecount -= 1)
    player.bonuscount != 0 && (player.bonuscount -= 1)
    if player.message_tics != 0
        player.message_tics -= 1
        player.message_tics <= 0 && (player.message = "")
    end
    nothing
end

function tick_fx!(world)
    keep = Any[]
    for mo in world.mobjs
        if mo.fx
            mo.tics -= 1
            mo.tics > 0 && push!(keep, mo)
        else
            push!(keep, mo)
        end
    end
    empty!(world.mobjs)
    append!(world.mobjs, keep)
    nothing
end

function weapon_body(player)
    player.psprite_body != "" && return player.psprite_body
    if player.psprite_state == "atk" || player.psprite_state == "fire"
        return get(WEAPON_FIRE_BODY, player.readyweapon, get(WEAPON_PATCH, player.readyweapon, "PISGA0"))
    end
    get(WEAPON_PATCH, player.readyweapon, "PISGA0")
end

function draw_weapon!(r, fb, player, leveltime)
    sx, sy = weapon_xy(player, leveltime)
    body = weapon_body(player)
    wad = r.res.wad
    n = check_num_for_name(wad, body)
    n < 0 && (n = check_num_for_name(wad, "PISGA0"))
    n >= 0 && draw_psprite!(r, fb, cache_lump_num(wad, n), sx, sy)
    flash = player.flash_tics > 0 ? player.psprite_flash : ""
    if flash != ""
        fn = check_num_for_name(wad, flash)
        fn >= 0 && draw_psprite!(r, fb, cache_lump_num(wad, fn), sx, sy)
    end
    nothing
end

const KEY_CARD = Dict(5 => 0, 6 => 1, 13 => 2, 40 => 3, 39 => 4, 38 => 5)

function take_key!(special, toucher)
    player = toucher === nothing ? nothing : toucher.player
    (player === nothing || special.alive == false) && return false
    card = get(KEY_CARD, special.doomednum, nothing)
    card === nothing && return false
    player.cards[card + 1] = true
    special.alive = false
    special.flags = 0
    special.sprite = ""
    true
end

mutable struct Carry
    health::Int
    armorpoints::Int
    armortype::Int
    ammo::Vector{Int}
    maxammo::Vector{Int}
    weaponowned::Vector{Bool}
    readyweapon::Int
    cheats::Int
end

function capture_carry(player)
    Carry(
        player.health, player.armorpoints, player.armortype,
        copy(player.ammo), copy(player.maxammo), copy(player.weaponowned),
        player.readyweapon, player.cheats,
    )
end

function apply_carry!(player, carry)
    player.health = carry.health
    player.mo.health = carry.health
    player.armorpoints = carry.armorpoints
    player.armortype = carry.armortype
    player.ammo = copy(carry.ammo)
    player.maxammo = copy(carry.maxammo)
    player.weaponowned = copy(carry.weaponowned)
    player.pendingweapon = WP_NOCHANGE
    player.readyweapon = carry.readyweapon
    player.psprite_state = "up"
    player.psprite_sy = WEAPONBOTTOM
    player.psprite_body = ""
    player.cheats = carry.cheats
    player.cards = fill(false, 6)
    player.damagecount = 0
    player.bonuscount = 0
    player.extralight = 0
    player.playerstate = PST_LIVE
    nothing
end

function held_at(held, key)
    get(held, key, false)
end

function build_ticcmd(held, turnheld, player, mousex=0, mousey=0, sensitivity=5, mouse_fire=false)
    cmd = empty_cmd()
    speed = held_at(held, "shift") ? 1 : 0
    strafe = held_at(held, "alt")
    turning = held_at(held, "right") || held_at(held, "left")
    held_count = turning ? turnheld + 1 : 0
    tspeed = held_count < 6 ? 2 : speed
    if strafe
        held_at(held, "right") && (cmd.sidemove += SIDEMOVE[speed + 1])
        held_at(held, "left") && (cmd.sidemove -= SIDEMOVE[speed + 1])
    else
        held_at(held, "right") && (cmd.angleturn -= ANGLETURN[tspeed + 1])
        held_at(held, "left") && (cmd.angleturn += ANGLETURN[tspeed + 1])
    end
    held_at(held, "up") && (cmd.forwardmove += FORWARDMOVE[speed + 1])
    held_at(held, "down") && (cmd.forwardmove -= FORWARDMOVE[speed + 1])
    held_at(held, "comma") && (cmd.sidemove -= SIDEMOVE[speed + 1])
    held_at(held, "period") && (cmd.sidemove += SIDEMOVE[speed + 1])
    held_at(held, "ctrl") && (cmd.buttons = Int(bor(cmd.buttons, BT_ATTACK)))
    (held_at(held, "space") || held_at(held, "e")) && (cmd.buttons = Int(bor(cmd.buttons, BT_USE)))
    picked = nothing
    if held_at(held, "1")
        if player !== nothing && player.readyweapon == WP_CHAINSAW
            picked = WP_FIST
        elseif player !== nothing && player.weaponowned[WP_CHAINSAW + 1]
            picked = WP_CHAINSAW
        else
            picked = WP_FIST
        end
    elseif held_at(held, "2")
        picked = WP_PISTOL
    elseif held_at(held, "3")
        picked = WP_SHOTGUN
    elseif held_at(held, "4")
        picked = WP_CHAINGUN
    elseif held_at(held, "5")
        picked = WP_MISSILE
    elseif held_at(held, "6")
        picked = WP_PLASMA
    elseif held_at(held, "7")
        picked = WP_BFG
    end
    if picked !== nothing
        cmd.buttons = Int(bor(cmd.buttons, BT_CHANGE + picked * (1 << BT_WEAPONSHIFT)))
    end
    if mousex != 0 || mousey != 0 || mouse_fire
        sens = (sensitivity + 5) / 10
        clampn(n) = n > 127 ? 127 : (n < -127 ? -127 : n)
        truncn(n) = n >= 0 ? floor(Int, n) : ceil(Int, n)
        mx = truncn(mousex * sens)
        my = truncn(mousey * sens)
        cmd.forwardmove = clampn(cmd.forwardmove + my)
        if strafe
            cmd.sidemove = clampn(cmd.sidemove + mx * 2)
        else
            cmd.angleturn -= mx * 8
        end
        mouse_fire && (cmd.buttons = Int(bor(cmd.buttons, BT_ATTACK)))
    end
    cmd, held_count
end

function set_message(player, text)
    player === nothing && return
    player.message = text === nothing ? "" : string(text)
    player.message_tics = 4 * 35
    nothing
end

function give_power(player, power)
    player === nothing && return false
    at = power + 1
    if power == PW_INVULNERABILITY
        player.powers[at] = 30 * 35
        return true
    end
    if power == PW_INVISIBILITY
        player.powers[at] = 60 * 35
        if player.mo !== nothing
            player.mo.flags = Int(bor(player.mo.flags, MF_SHADOW))
        end
        return true
    end
    if power == PW_INFRARED
        player.powers[at] = 120 * 35
        return true
    end
    if power == PW_IRONFEET
        player.powers[at] = 60 * 35
        return true
    end
    if power == PW_STRENGTH
        if player.health < 100
            player.health = min(100, player.health + 100)
            player.mo !== nothing && (player.mo.health = player.health)
        end
        player.powers[at] = 1
        return true
    end
    player.powers[at] != 0 && return false
    player.powers[at] = 1
    true
end

end

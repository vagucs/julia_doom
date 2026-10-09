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
# Olhar, perseguir, atacar e cair, a partir de enemy.py.

module Enemy

using ..Compat
using ..Collision
using ..Info
using ..Rng
using ..Tables
using ..Thinker
using ..Specials
using ..Wad
using ..Player

export damage_mobj, spawn_player_missile, noise_alert, p_xy_movement, mobj_z, call_action, p_random

const FRACUNIT = 65536
const ANG45 = 536870912
const ANG90 = 1073741824
const ANG180 = 2147483648
const ANG270 = 3221225472
const FRICTION = 59392
const GRAVITY = FRACUNIT
const MAXMOVE = 30 * FRACUNIT
const MELEERANGE = 64 * FRACUNIT
const MISSILERANGE = 32 * 64 * FRACUNIT
const SKULLSPEED = 20 * FRACUNIT
const STOPSPEED = 4096
const FLOATSPEED = 4 * FRACUNIT
const TRACEANGLE = 201326592
const FATSPREAD = fld(ANG90, 8)
const MAX_SKULLS = 21
const VIEWHEIGHT = 41 * FRACUNIT
const MF_AMBUSH = 32
const MF_CORPSE = 1048576
const MF_COUNTKILL = 4194304
const MF_DROPOFF = 1024
const MF_DROPPED = 131072
const MF_FLOAT = 16384
const MF_INFLOAT = 2097152
const MF_JUSTHIT = 64
const MF_JUSTATTACKED = 128
const MF_MISSILE = 65536
const MF_NOCLIP = 4096
const MF_NOGRAVITY = 512
const MF_SHADOW = 262144
const MF_SHOOTABLE = 4
const MF_SKULLFLY = 16777216
const MF_SOLID = 2
const ML_SOUNDBLOCK = 64
const ML_TWOSIDED = 4
const SK_EASY = 1
const SK_NIGHTMARE = 4
const CF_NOMOMENTUM = 4
const DI_EAST, DI_NE, DI_NORTH, DI_NW = 0, 1, 2, 3
const DI_WEST, DI_SW, DI_SOUTH, DI_SE = 4, 5, 6, 7
const DI_NODIR = 8
const XSPEED = (FRACUNIT, 47000, 0, -47000, -FRACUNIT, -47000, 0, 47000)
const YSPEED = (0, 47000, FRACUNIT, 47000, 0, -47000, -FRACUNIT, -47000)
const OPPOSITE = (4, 5, 6, 7, 0, 1, 2, 3, 8)
const DIAGS = (DI_NW, DI_NE, DI_SW, DI_SE)

brain_target_on = 0
brain_targets = Any[]

has(flags, bit) = band(flags, bit) != 0
mi(mo) = info_at(mo.typ)
play(game, name) = (game !== nothing && game.start_sound !== nothing && name != "") && game.start_sound(name)
trunc0(n) = trunc(Int, n)

function kill_monster(mo, game, source)
    row = mi(mo)
    mo.flags = Int(band(mo.flags, bnot(MF_SHOOTABLE + MF_FLOAT + MF_SKULLFLY)))
    mo.flags = Int(bor(mo.flags, MF_CORPSE + MF_DROPOFF))
    mo.height = fld(mo.height, 4)
    if source !== nothing && source.player !== nothing && has(mo.flags, MF_COUNTKILL)
        source.player.killcount += 1
    end
    st = row.deathstate
    mo.health < -row.spawnhealth && row.xdeathstate != 0 && (st = row.xdeathstate)
    set_mobj_state!(mo, st, game.world, game)
    mo.alive == false && return
    mo.tics -= Int(band(p_random(), 3))
    mo.tics < 1 && (mo.tics = 1)
    drop = nothing
    mo.typ == MT_POSSESSED && (drop = MT_CLIP)
    mo.typ == MT_SHOTGUY && (drop = MT_SHOTGUN)
    mo.typ == MT_CHAINGUY && (drop = MT_CHAINGUN)
    if drop !== nothing
        item = spawn_mobj!(game.world, mo.x, mo.y, ONFLOORZ, drop, game)
        item.flags = Int(bor(item.flags, MF_DROPPED))
    end
    nothing
end

function pain_or_wake(game, target, source)
    row = info_at(target.typ)
    if p_random() < row.painchance && !has(target.flags, MF_SKULLFLY)
        target.flags = Int(bor(target.flags, MF_JUSTHIT))
        row.painstate != 0 && set_mobj_state!(target, row.painstate, game.world, game)
    end
    target.reactiontime = 0
    if source !== nothing && source !== target && target.player === nothing
        target.target = source
        if target.istate == row.spawnstate && row.seestate != 0
            set_mobj_state!(target, row.seestate, game.world, game)
        end
    end
    nothing
end

function damage_mobj(game, target, source, damage, inflictor=source)
    (target === nothing || target.alive == false || !has(target.flags, MF_SHOOTABLE)) && return
    if target.player !== nothing && game.skill == 0
        damage = fld(damage, 2)
    end
    src = inflictor === nothing ? source : inflictor
    skip_saw = source !== nothing && source.player !== nothing && source.player.readyweapon == 7
    if src !== nothing && !has(target.flags, MF_NOCLIP) && !skip_saw
        ang = angle_to(src.x, src.y, target.x, target.y)
        row = info_at(target.typ)
        mass = row.mass == 0 ? 100 : row.mass
        thrust = fld(damage * 8192 * 100, mass)
        if damage < 40 && damage > target.health && target.z - src.z > 64 * FRACUNIT && band(p_random(), 1) != 0
            ang = as_u32(Int64(ang) + ANG180)
            thrust *= 4
        end
        target.momx += Int(fixed_mul(thrust, fine_cos(ang)))
        target.momy += Int(fixed_mul(thrust, fine_sin(ang)))
    end
    if target.player !== nothing
        Player.damage_mobj(target, source, damage, inflictor)
        return
    end
    target.health -= damage
    if target.health <= 0
        kill_monster(target, game, source)
        return
    end
    pain_or_wake(game, target, source)
    nothing
end

function recursive_sound(world, sec, soundblocks, target)
    if sec.validcount == world.validcount && sec.soundtraversed <= soundblocks + 1
        return
    end
    sec.validcount = world.validcount
    sec.soundtraversed = soundblocks + 1
    sec.soundtarget = target
    for check in sec.lines
        has(check.flags, ML_TWOSIDED) || continue
        opentop, openbottom, _ = line_opening(check)
        opentop - openbottom > 0 || continue
        other = check.frontsector !== sec ? check.frontsector : check.backsector
        other === nothing && continue
        if has(check.flags, ML_SOUNDBLOCK)
            soundblocks == 0 && recursive_sound(world, other, 1, target)
        else
            recursive_sound(world, other, soundblocks, target)
        end
    end
end

function noise_alert(world, emitter, game)
    emitter === nothing && return
    sec = point_in_subsector(world, emitter.x, emitter.y).sector
    world.validcount += 1
    recursive_sound(world, sec, 0, emitter)
    nothing
end

function play_see_sound(mo, game)
    s = mi(mo).seesound
    s == "" && return
    if s == "posit1"
        s = ("posit1", "posit2", "posit3")[(p_random() % 3) + 1]
    elseif s == "bgsit1"
        s = ("bgsit1", "bgsit2")[(p_random() % 2) + 1]
    end
    play(game, s)
end

function play_death_sound(mo, game)
    s = mi(mo).deathsound
    s == "" && return
    if s == "podth1"
        s = ("podth1", "podth2", "podth3")[(p_random() % 3) + 1]
    elseif s == "bgdth1"
        s = ("bgdth1", "bgdth2")[(p_random() % 2) + 1]
    end
    play(game, s)
end

function look_for_players(world, mo, player_mo, allaround)
    player_mo === nothing && return false
    c = 0
    stop = Int(band(mo.lastlook - 1, 3))
    guard = 0
    while guard < 32
        guard += 1
        if mo.lastlook != 0
            mo.lastlook = Int(band(mo.lastlook + 1, 3))
        else
            if c == 2 || mo.lastlook == stop
                return false
            end
            c += 1
            skip = false
            if player_mo.health <= 0 || !has(player_mo.flags, MF_SHOOTABLE)
                mo.lastlook = Int(band(mo.lastlook + 1, 3))
                skip = true
            elseif !check_sight(world, mo, player_mo)
                mo.lastlook = Int(band(mo.lastlook + 1, 3))
                skip = true
            elseif !allaround
                an = as_u32(Int64(angle_to(mo.x, mo.y, player_mo.x, player_mo.y)) - Int64(mo.angle))
                if an > ANG90 && an < ANG270
                    dist = approx_distance(player_mo.x - mo.x, player_mo.y - mo.y)
                    if dist > MELEERANGE
                        mo.lastlook = Int(band(mo.lastlook + 1, 3))
                        skip = true
                    end
                end
            end
            if !skip
                mo.target = player_mo
                return true
            end
        end
    end
    false
end

function face_target(mo, target)
    mo.angle = angle_to(mo.x, mo.y, target.x, target.y)
    if has(target.flags, MF_SHADOW)
        mo.angle = as_u32(Int64(mo.angle) + Int64(p_random() - p_random()) * 2097152)
    end
    nothing
end

function face_movedir(mo)
    (mo.movedir < 0 || mo.movedir >= 8) && return
    mo.angle = as_u32(band(mo.angle, 3758096384))
    delta = as_i32(Int64(mo.angle) - mo.movedir * ANG45)
    if delta > 0
        mo.angle = as_u32(Int64(mo.angle) - ANG45)
    elseif delta < 0
        mo.angle = as_u32(Int64(mo.angle) + ANG45)
    end
    nothing
end

function move_step(world, mo, speed, game)
    (mo.movedir < 0 || mo.movedir >= 8) && return false
    nx = mo.x + speed * XSPEED[mo.movedir + 1]
    ny = mo.y + speed * YSPEED[mo.movedir + 1]
    if !try_move!(world, mo, nx, ny, game)
        if has(mo.flags, MF_FLOAT) && Collision.floatok
            mo.z += mo.z < Collision.tmfloorz ? FLOATSPEED : -FLOATSPEED
            mo.flags = Int(bor(mo.flags, MF_INFLOAT))
            return true
        end
        hits = Collision.last_spechit
        (hits === nothing || isempty(hits)) && return false
        mo.movedir = DI_NODIR
        good = false
        for i in length(hits):-1:1
            ln = hits[i]
            if ln.special != 0 && game !== nothing && game.use_special !== nothing && game.use_special(ln, mo, 0)
                good = true
            end
        end
        return good
    end
    mo.flags = Int(band(mo.flags, bnot(MF_INFLOAT)))
    has(mo.flags, MF_FLOAT) || (mo.z = mo.floorz)
    true
end

function new_chase_dir(world, mo, game)
    target = mo.target
    target === nothing && return
    old = mo.movedir
    turn = DI_NODIR
    if 0 <= old < 8
        turn = OPPOSITE[old + 1]
    end
    dx = target.x - mo.x
    dy = target.y - mo.y
    d2 = DI_NODIR
    d3 = DI_NODIR
    dx > 10 * FRACUNIT && (d2 = DI_EAST)
    dx < -10 * FRACUNIT && (d2 = DI_WEST)
    dy < -10 * FRACUNIT && (d3 = DI_SOUTH)
    dy > 10 * FRACUNIT && (d3 = DI_NORTH)
    speed = mi(mo).speed
    if d2 != DI_NODIR && d3 != DI_NODIR
        mo.movedir = DIAGS[(dy < 0 ? 2 : 0) + (dx > 0 ? 1 : 0) + 1]
        if mo.movedir != turn && move_step(world, mo, speed, game)
            mo.movecount = Int(band(p_random(), 15))
            return
        end
    end
    if p_random() > 200 || abs(dy) > abs(dx)
        d2, d3 = d3, d2
    end
    d2 == turn && (d2 = DI_NODIR)
    d3 == turn && (d3 = DI_NODIR)
    if d2 != DI_NODIR
        mo.movedir = d2
        if move_step(world, mo, speed, game)
            mo.movecount = Int(band(p_random(), 15))
            return
        end
    end
    if d3 != DI_NODIR
        mo.movedir = d3
        if move_step(world, mo, speed, game)
            mo.movecount = Int(band(p_random(), 15))
            return
        end
    end
    if old != DI_NODIR
        mo.movedir = old
        if move_step(world, mo, speed, game)
            mo.movecount = Int(band(p_random(), 15))
            return
        end
    end
    start = Int(band(p_random(), 1))
    dirs = start != 0 ? collect(0:7) : collect(7:-1:0)
    for tdir in dirs
        if tdir != turn
            mo.movedir = tdir
            if move_step(world, mo, speed, game)
                mo.movecount = Int(band(p_random(), 15))
                return
            end
        end
    end
    if turn != DI_NODIR
        mo.movedir = turn
        if move_step(world, mo, speed, game)
            mo.movecount = Int(band(p_random(), 15))
            return
        end
    end
    mo.movedir = DI_NODIR
    mo.movecount = Int(band(p_random(), 15))
    nothing
end

function missile_ok(world, mo, target, dist, has_melee)
    check_sight(world, mo, target) || return false
    if has(mo.flags, MF_JUSTHIT)
        mo.flags = Int(band(mo.flags, bnot(MF_JUSTHIT)))
        return true
    end
    mo.reactiontime != 0 && return false
    d = dist - 64 * FRACUNIT
    has_melee || (d -= 128 * FRACUNIT)
    d = Int(shar(d, 16))
    mo.typ == MT_VILE && d > 14 * 64 && return false
    if mo.typ == MT_UNDEAD
        d < 196 && return false
        d = Int(shar(d, 1))
    end
    if mo.typ == MT_CYBORG || mo.typ == MT_SPIDER || mo.typ == MT_SKULL
        d = Int(shar(d, 1))
    end
    d > 200 && (d = 200)
    mo.typ == MT_CYBORG && d > 160 && (d = 160)
    p_random() >= d
end

function look(world, mo, player_mo, game)
    mo.threshold = 0
    see = false
    sec = point_in_subsector(world, mo.x, mo.y).sector
    targ = sec.soundtarget
    if targ !== nothing && has(targ.flags, MF_SHOOTABLE)
        mo.target = targ
        see = has(mo.flags, MF_AMBUSH) ? check_sight(world, mo, targ) : true
    end
    if !see && !look_for_players(world, mo, player_mo, false)
        return
    end
    mo.movedir = DI_NODIR
    mo.movecount = 0
    play_see_sound(mo, game)
    set_mobj_state!(mo, mi(mo).seestate, world, game)
    nothing
end

function chase(world, mo, player_mo, game)
    row = mi(mo)
    mo.reactiontime != 0 && (mo.reactiontime -= 1)
    if mo.threshold != 0
        target = mo.target
        if target === nothing || target.health <= 0
            mo.threshold = 0
        else
            mo.threshold -= 1
        end
    end
    mo.movedir < 8 && face_movedir(mo)
    target = mo.target
    if target === nothing || !has(target.flags, MF_SHOOTABLE)
        look_for_players(world, mo, player_mo, true) && return
        set_mobj_state!(mo, row.spawnstate, world, game)
        return
    end
    if has(mo.flags, MF_JUSTATTACKED)
        mo.flags = Int(band(mo.flags, bnot(MF_JUSTATTACKED)))
        if game.skill != SK_NIGHTMARE && game.fastparm != true
            new_chase_dir(world, mo, game)
        end
        return
    end
    dist = approx_distance(target.x - mo.x, target.y - mo.y)
    melee_range = MELEERANGE - 20 * FRACUNIT + target.radius
    if row.meleestate != 0 && dist < melee_range && check_sight(world, mo, target)
        row.attacksound != "" && play(game, row.attacksound)
        set_mobj_state!(mo, row.meleestate, world, game)
        return
    end
    if row.missilestate != 0
        skip = game.skill < SK_NIGHTMARE && game.fastparm != true && mo.movecount != 0
        if !skip && missile_ok(world, mo, target, dist, row.meleestate != 0)
            set_mobj_state!(mo, row.missilestate, world, game)
            mo.flags = Int(bor(mo.flags, MF_JUSTATTACKED))
            return
        end
    end
    mo.movecount -= 1
    if mo.movecount < 0 || !move_step(world, mo, row.speed, game)
        new_chase_dir(world, mo, game)
    end
    if row.activesound != "" && p_random() < 3
        play(game, row.activesound)
    end
    nothing
end

function check_missile_spawn(mo)
    mo.tics -= Int(band(p_random(), 3))
    mo.tics < 1 && (mo.tics = 1)
    mo.x += Int(shar(mo.momx, 1))
    mo.y += Int(shar(mo.momy, 1))
    mo.z += Int(shar(mo.momz, 1))
    nothing
end

function spawn_missile_mt(world, source, dest, typ, game, ang=nothing)
    row = info_at(typ)
    speed = row.speed
    dest === nothing && (dest = source)
    if ang === nothing
        ang = angle_to(source.x, source.y, dest.x, dest.y)
        if has(dest.flags, MF_SHADOW)
            ang = as_u32(Int64(ang) + Int64(p_random() - p_random()) * 1048576)
        end
    end
    dist = approx_distance(dest.x - source.x, dest.y - source.y)
    steps = speed == 0 ? 1 : fld(dist, speed)
    steps < 1 && (steps = 1)
    mo = spawn_mobj!(world, source.x, source.y, source.z + 32 * FRACUNIT, typ, game)
    mo.target = source
    mo.angle = ang
    mo.momx = Int(fixed_mul(speed, fine_cos(ang)))
    mo.momy = Int(fixed_mul(speed, fine_sin(ang)))
    mo.momz = trunc0((dest.z - source.z) / steps)
    check_missile_spawn(mo)
    mo
end

function spawn_player_missile(world, source, kind)
    typ = MT_BFG
    kind == "rocket" && (typ = MT_ROCKET)
    kind == "plasma" && (typ = MT_PLASMA)
    ang, slope = Collision.missile_aim(world, source)
    spd = info_at(typ).speed
    mo = spawn_mobj!(world, source.x, source.y, source.z + 32 * FRACUNIT, typ, nothing)
    mo.target = source
    mo.angle = ang
    mo.momx = Int(fixed_mul(spd, fine_cos(ang)))
    mo.momy = Int(fixed_mul(spd, fine_sin(ang)))
    mo.momz = Int(fixed_mul(spd, slope))
    check_missile_spawn(mo)
    mo
end

function missile_victim(world, mo)
    spots = mo.tmx != mo.x || mo.tmy != mo.y ? ((mo.x, mo.y, mo.z), (mo.tmx, mo.tmy, mo.z)) : ((mo.x, mo.y, mo.z),)
    best = nothing
    best_dist = typemax(Int)
    for other in world.mobjs
        if mo.target !== nothing && Collision.same_species(mo.target, other) && other !== mo.target && other.typ != MT_PLAYER
            continue
        end
        for (x, y, z) in spots
            Collision.missile_reaches(mo, other, x, y, z) || continue
            dist = max(abs(other.x - x), abs(other.y - y))
            if dist < best_dist
                best_dist = dist
                best = other
            end
        end
    end
    best
end

function radius_attack(world, spot, source, damage, game)
    list = copy(world.mobjs)
    for other in list
        other === spot && continue
        has(other.flags, MF_SHOOTABLE) || continue
        (other.typ == MT_CYBORG || other.typ == MT_SPIDER) && continue
        dx = abs(other.x - spot.x)
        dy = abs(other.y - spot.y)
        dist = max(dx, dy) - other.radius
        dist < 0 && (dist = 0)
        dist = Int(shar(dist, 16))
        if dist < damage && check_sight(world, other, spot)
            src = source === nothing ? spot : source
            game.damage_mobj(other, src, damage - dist, spot)
        end
    end
end

function explode_missile(world, mo, game, hit)
    if hit === nothing
        hit = mo.struck !== nothing ? mo.struck : missile_victim(world, mo)
    end
    mo.struck = nothing
    if hit !== nothing && game !== nothing && game.damage_mobj !== nothing
        src = mo.target === nothing ? mo : mo.target
        dmg = mo.damage == 0 ? mi(mo).damage : mo.damage
        game.damage_mobj(hit, src, dmg * ((p_random() % 8) + 1), mo)
    end
    mo.momx = 0
    mo.momy = 0
    mo.momz = 0
    mo.flags = Int(band(mo.flags, bnot(MF_MISSILE)))
    set_mobj_state!(mo, mi(mo).deathstate, world, game)
    nothing
end

function p_xy_movement(world, mo, game)
    if mo.momx == 0 && mo.momy == 0
        if has(mo.flags, MF_SKULLFLY)
            mo.flags = Int(band(mo.flags, bnot(MF_SKULLFLY)))
            mo.momx = 0
            mo.momy = 0
            mo.momz = 0
            set_mobj_state!(mo, mi(mo).spawnstate, world, game)
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
            ptryx = mo.x + trunc0(xmove / 2)
            ptryy = mo.y + trunc0(ymove / 2)
            xmove = trunc0(xmove / 2)
            ymove = trunc0(ymove / 2)
        else
            ptryx = mo.x + xmove
            ptryy = mo.y + ymove
            xmove, ymove = 0, 0
        end
        if has(mo.flags, MF_NOCLIP)
            unset_thing_position!(world, mo)
            mo.x, mo.y = ptryx, ptryy
            set_thing_position!(world, mo)
        elseif try_move!(world, mo, ptryx, ptryy, game)
        elseif mo.player !== nothing
            slide_move!(world, mo, mo.momx, mo.momy, game)
        elseif has(mo.flags, MF_MISSILE)
            line = Collision.ceilingline
            sky = -1
            if game !== nothing && game.res !== nothing
                sky = game.res.skyflatnum
            end
            if line !== nothing && line.backsector !== nothing && line.backsector.ceilingpic == sky
                remove_mobj!(world, mo)
                return
            end
            explode_missile(world, mo, game, nothing)
            return
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
    (has(mo.flags, MF_MISSILE) || has(mo.flags, MF_SKULLFLY)) && return
    mo.z > mo.floorz && return
    if has(mo.flags, MF_CORPSE)
        lim = fld(FRACUNIT, 4)
        if mo.momx > lim || mo.momx < -lim || mo.momy > lim || mo.momy < -lim
            sec = point_in_subsector(world, mo.x, mo.y).sector
            mo.floorz != Int(sec.floorheight) && return
        end
    end
    stopped = -STOPSPEED < mo.momx < STOPSPEED && -STOPSPEED < mo.momy < STOPSPEED
    if player !== nothing
        stopped = stopped && player.cmd.forwardmove == 0 && player.cmd.sidemove == 0
    end
    if stopped
        if player !== nothing
            n = mo.istate - S_PLAY_RUN1
            if 0 <= n < 4
                set_mobj_state!(mo, S_PLAY, world, game)
            end
        end
        mo.momx = 0
        mo.momy = 0
    else
        mo.momx = Int(fixed_mul(mo.momx, FRICTION))
        mo.momy = Int(fixed_mul(mo.momy, FRICTION))
    end
    nothing
end

function mobj_z(mo, world, game)
    player = mo.player
    if player !== nothing && mo.z < mo.floorz
        player.viewheight -= mo.floorz - mo.z
        player.deltaviewheight = Int(shar(VIEWHEIGHT - player.viewheight, 3))
    end
    mo.z += mo.momz
    if has(mo.flags, MF_FLOAT) && mo.target !== nothing && !has(mo.flags, MF_SKULLFLY) && !has(mo.flags, MF_INFLOAT)
        dist = approx_distance(mo.x - mo.target.x, mo.y - mo.target.y)
        delta = (mo.target.z + Int(shar(mo.height, 1))) - mo.z
        if delta < 0 && dist < -(delta * 3)
            mo.z -= FLOATSPEED
        elseif delta > 0 && dist < (delta * 3)
            mo.z += FLOATSPEED
        end
    end
    if mo.z <= mo.floorz
        if mo.momz < 0
            if player !== nothing && mo.momz < -GRAVITY * 8
                player.deltaviewheight = Int(shar(mo.momz, 3))
                play(game, "oof")
            end
            mo.momz = 0
        end
        mo.z = mo.floorz
        if has(mo.flags, MF_SKULLFLY) && !has(mo.flags, MF_MISSILE)
            mo.momz = -mo.momz
        end
        if has(mo.flags, MF_MISSILE) && !has(mo.flags, MF_NOCLIP)
            explode_missile(world, mo, game, nothing)
            return
        end
    elseif !has(mo.flags, MF_NOGRAVITY)
        mo.momz = mo.momz == 0 ? -GRAVITY * 2 : mo.momz - GRAVITY
    end
    if mo.z + mo.height > mo.ceilingz
        mo.momz > 0 && (mo.momz = 0)
        mo.z = mo.ceilingz - mo.height
        has(mo.flags, MF_SKULLFLY) && (mo.momz = -mo.momz)
        if has(mo.flags, MF_MISSILE) && !has(mo.flags, MF_NOCLIP)
            explode_missile(world, mo, game, nothing)
        end
    end
    nothing
end

function skull_attack(mo, game)
    dest = mo.target
    dest === nothing && return
    mo.flags = Int(bor(mo.flags, MF_SKULLFLY))
    play(game, "sklatk")
    face_target(mo, dest)
    mo.momx = Int(fixed_mul(SKULLSPEED, fine_cos(mo.angle)))
    mo.momy = Int(fixed_mul(SKULLSPEED, fine_sin(mo.angle)))
    dist = approx_distance(dest.x - mo.x, dest.y - mo.y)
    steps = fld(dist, SKULLSPEED)
    steps < 1 && (steps = 1)
    mo.momz = trunc0((dest.z + fld(dest.height, 2) - mo.z) / steps)
    nothing
end

function tracer_home(mo)
    dest = mo.tracer
    (dest === nothing || dest.health <= 0) && return
    exact = angle_to(mo.x, mo.y, dest.x, dest.y)
    diff = as_u32(Int64(exact) - Int64(mo.angle))
    if diff > 2147483648
        mo.angle = as_u32(Int64(mo.angle) - TRACEANGLE)
        if as_u32(Int64(exact) - Int64(mo.angle)) < 2147483648
            mo.angle = exact
        end
    else
        mo.angle = as_u32(Int64(mo.angle) + TRACEANGLE)
        if as_u32(Int64(exact) - Int64(mo.angle)) > 2147483648
            mo.angle = exact
        end
    end
    speed = mi(mo).speed
    mo.momx = Int(fixed_mul(speed, fine_cos(mo.angle)))
    mo.momy = Int(fixed_mul(speed, fine_sin(mo.angle)))
    dist = approx_distance(dest.x - mo.x, dest.y - mo.y)
    steps = speed == 0 ? 1 : fld(dist, speed)
    steps < 1 && (steps = 1)
    mo.momz = trunc0((dest.z + 40 * FRACUNIT - mo.z) / steps)
    nothing
end

function vile_chase(world, mo, game)
    for other in world.mobjs
        other === mo && continue
        has(other.flags, MF_CORPSE) || continue
        other.health > 0 && continue
        row = info_at(other.typ)
        row.raisestate == 0 && continue
        maxdist = mo.radius + other.radius
        if abs(other.x - mo.x) <= maxdist && abs(other.y - mo.y) <= maxdist
            set_mobj_state!(mo, S_VILE_HEAL1, world, game)
            play(game, "slop")
            set_mobj_state!(other, row.raisestate, world, game)
            other.flags = row.flags
            other.health = row.spawnhealth
            other.height = row.height
            other.radius = row.radius
            other.target = nothing
            other.alive = true
            other.z = other.floorz
            return true
        end
    end
    false
end

function pain_shoot_skull(world, actor, game, ang)
    n = 0
    for other in world.mobjs
        other.typ == MT_SKULL && other.health > 0 && (n += 1)
    end
    n >= MAX_SKULLS && return
    pre = 4 * FRACUNIT + fld(3 * actor.radius, 2)
    x = actor.x + Int(fixed_mul(pre, fine_cos(ang)))
    y = actor.y + Int(fixed_mul(pre, fine_sin(ang)))
    skull = spawn_mobj!(world, x, y, actor.z, MT_SKULL, game)
    skull.angle = ang
    if check_position(world, skull, skull.x, skull.y, nothing).blocked
        game.damage_mobj(skull, actor, 10000, actor)
        return
    end
    skull.target = actor.target
    skull_attack(skull, game)
    nothing
end

function alive_of_type(world, typ)
    for other in world.mobjs
        other.typ == typ && other.health > 0 && return true
    end
    false
end

function boss_death(world, mo, game)
    alive_of_type(world, mo.typ) && return
    spec = game.specials
    spec === nothing && return
    commercial = game.wad !== nothing && check_num_for_name(game.wad, "MAP01") >= 0
    if commercial && game.mapn == 7
        if mo.typ == MT_FATSO
            do_floor_tag(spec, 666, lowest_floor, -1)
        elseif mo.typ == MT_BABY
            raise_to_texture_tag(spec, 667)
        end
        return
    end
    commercial && return
    if game.episode == 1 && game.mapn == 8 && mo.typ == MT_BRUISER
        do_floor_tag(spec, 666, lowest_floor, -1)
    elseif game.episode == 2 && game.mapn == 8 && mo.typ == MT_CYBORG
        spec.exit_requested = true
    elseif game.episode == 3 && game.mapn == 8 && mo.typ == MT_SPIDER
        spec.exit_requested = true
    elseif game.episode == 4 && game.mapn == 6 && mo.typ == MT_CYBORG
        do_floor_tag(spec, 666, lowest_floor, -1)
    elseif game.episode == 4 && game.mapn == 8 && mo.typ == MT_BRUISER
        do_floor_tag(spec, 666, lowest_floor, -1)
    end
    nothing
end

function spawn_fly(world, cube, game)
    dest = cube.target === nothing ? cube : cube.target
    r = p_random()
    typ = MT_BRUISER
    if r < 50
        typ = MT_TROOP
    elseif r < 90
        typ = MT_SERGEANT
    elseif r < 120
        typ = MT_SHADOWS
    elseif r < 130
        typ = MT_PAIN
    elseif r < 160
        typ = MT_HEAD
    elseif r < 162
        typ = MT_VILE
    elseif r < 172
        typ = MT_UNDEAD
    elseif r < 192
        typ = MT_BABY
    elseif r < 222
        typ = MT_FATSO
    elseif r < 246
        typ = MT_KNIGHT
    end
    play(game, "telept")
    spawned = spawn_mobj!(world, dest.x, dest.y, dest.z, typ, game)
    spawned.angle = dest.angle
    remove_mobj!(world, cube)
    nothing
end

function bfg_spray(world, ball, game)
    shooter = ball.target
    shooter === nothing && return
    for i in 0:39
        an = as_u32(Int64(shooter.angle) - fld(ANG90, 2) + fld(ANG90, 40) * i)
        target = aim_line_attack(world, shooter, an, 16 * 64 * FRACUNIT)
        if target !== nothing
            damage = 0
            for _ in 1:15
                damage += Int(band(p_random(), 7)) + 1
            end
            game.damage_mobj(target, shooter, damage, ball)
        end
    end
end

function call_action(name, mo, world, game)
    global brain_target_on, brain_targets
    pl = (game !== nothing && game.player !== nothing) ? game.player.mo : nothing
    if name == "Look"
        look(world, mo, pl, game)
    elseif name == "Chase"
        chase(world, mo, pl, game)
    elseif name == "FaceTarget"
        mo.target !== nothing && face_target(mo, mo.target)
    elseif name == "Fall"
        mo.flags = Int(band(mo.flags, bnot(MF_SOLID)))
    elseif name == "Scream"
        play_death_sound(mo, game)
    elseif name == "XScream"
        play(game, "slop")
    elseif name == "Pain"
        s = mi(mo).painsound
        s != "" && play(game, s)
    elseif name == "Explode"
        radius_attack(world, mo, mo.target, 128, game)
    elseif name == "PosAttack" || name == "CPosAttack"
        mo.target === nothing && return
        face_target(mo, mo.target)
        slope = aim_slope(world, mo, mo.angle, MISSILERANGE)
        play(game, name == "PosAttack" ? "pistol" : "shotgn")
        saved = mo.angle
        mo.angle = as_u32(Int64(saved) + Int64(p_random() - p_random()) * 1048576)
        line_attack!(world, mo, ((p_random() % 5) + 1) * 3, game, MISSILERANGE, mo.angle, slope)
        mo.angle = saved
    elseif name == "SPosAttack"
        mo.target === nothing && return
        face_target(mo, mo.target)
        slope = aim_slope(world, mo, mo.angle, MISSILERANGE)
        play(game, "shotgn")
        saved = mo.angle
        for _ in 1:3
            mo.angle = as_u32(Int64(saved) + Int64(p_random() - p_random()) * 1048576)
            line_attack!(world, mo, ((p_random() % 5) + 1) * 3, game, MISSILERANGE, mo.angle, slope)
        end
        mo.angle = saved
    elseif name == "CPosRefire" || name == "SpidRefire"
        mo.target !== nothing && face_target(mo, mo.target)
        keep = name == "SpidRefire" ? 10 : 40
        p_random() < keep && return
        if mo.target === nothing || mo.target.health <= 0 || !check_sight(world, mo, mo.target)
            set_mobj_state!(mo, mi(mo).seestate, world, game)
        end
    elseif name == "TroopAttack"
        mo.target === nothing && return
        face_target(mo, mo.target)
        dist = approx_distance(mo.target.x - mo.x, mo.target.y - mo.y)
        if dist < MELEERANGE + mo.radius
            play(game, "claw")
            game.damage_mobj(mo.target, mo, ((p_random() % 8) + 1) * 3)
        else
            spawn_missile_mt(world, mo, mo.target, MT_TROOPSHOT, game)
        end
    elseif name == "SargAttack"
        mo.target === nothing && return
        face_target(mo, mo.target)
        dist = approx_distance(mo.target.x - mo.x, mo.target.y - mo.y)
        if dist < MELEERANGE + mo.radius
            game.damage_mobj(mo.target, mo, ((p_random() % 8) + 1) * 4)
        end
    elseif name == "HeadAttack"
        mo.target === nothing && return
        face_target(mo, mo.target)
        dist = approx_distance(mo.target.x - mo.x, mo.target.y - mo.y)
        if dist < MELEERANGE + mo.radius
            game.damage_mobj(mo.target, mo, ((p_random() % 8) + 1) * 10)
        else
            spawn_missile_mt(world, mo, mo.target, MT_HEADSHOT, game)
        end
    elseif name == "BruisAttack"
        mo.target === nothing && return
        face_target(mo, mo.target)
        dist = approx_distance(mo.target.x - mo.x, mo.target.y - mo.y)
        if dist < MELEERANGE + mo.radius
            game.damage_mobj(mo.target, mo, ((p_random() % 8) + 1) * 10)
        else
            spawn_missile_mt(world, mo, mo.target, MT_BRUISERSHOT, game)
        end
    elseif name == "SkullAttack"
        skull_attack(mo, game)
    elseif name == "CyberAttack"
        mo.target === nothing && return
        face_target(mo, mo.target)
        spawn_missile_mt(world, mo, mo.target, MT_ROCKET, game)
    elseif name == "BspiAttack"
        mo.target === nothing && return
        face_target(mo, mo.target)
        spawn_missile_mt(world, mo, mo.target, MT_ARACHPLAZ, game)
    elseif name == "Metal"
        play(game, "metal")
        chase(world, mo, pl, game)
    elseif name == "BabyMetal"
        play(game, "bspwlk")
        chase(world, mo, pl, game)
    elseif name == "Hoof"
        play(game, "hoof")
        chase(world, mo, pl, game)
    elseif name == "PainAttack"
        mo.target === nothing && return
        face_target(mo, mo.target)
        pain_shoot_skull(world, mo, game, mo.angle)
    elseif name == "PainDie"
        mo.flags = Int(band(mo.flags, bnot(MF_SOLID)))
        pain_shoot_skull(world, mo, game, as_u32(Int64(mo.angle) + ANG90))
        pain_shoot_skull(world, mo, game, as_u32(Int64(mo.angle) + ANG90 * 2))
        pain_shoot_skull(world, mo, game, as_u32(Int64(mo.angle) + ANG270))
    elseif name == "KeenDie"
        mo.flags = Int(band(mo.flags, bnot(MF_SOLID)))
        if !alive_of_type(world, MT_KEEN) && game.specials !== nothing
            do_door_tag(game.specials, 666, VLD_BLAZEOPEN)
        end
    elseif name == "BossDeath"
        boss_death(world, mo, game)
    elseif name == "VileChase"
        vile_chase(world, mo, game) || chase(world, mo, pl, game)
    elseif name == "VileStart"
        play(game, "vilatk")
    elseif name == "VileTarget"
        mo.target === nothing && return
        face_target(mo, mo.target)
        fog = spawn_mobj!(world, mo.target.x, mo.target.y, mo.target.z, MT_FIRE, game)
        mo.tracer = fog
        fog.target = mo
        fog.tracer = mo.target
    elseif name == "VileAttack"
        dest = mo.target
        (dest === nothing || !check_sight(world, mo, dest)) && return
        play(game, "vilatk")
        game.damage_mobj(dest, mo, 20)
        radius_attack(world, dest, mo, 70, game)
    elseif name == "StartFire" || name == "Fire" || name == "FireCrackle"
        name == "StartFire" && play(game, "flamst")
        name == "FireCrackle" && play(game, "flame")
        dest = mo.tracer
        (dest === nothing || mo.target === nothing) && return
        mo.x, mo.y, mo.z = dest.x, dest.y, dest.z
    elseif name == "Tracer"
        band(game.leveltime, 3) != 0 && return
        tracer_home(mo)
    elseif name == "SkelWhoosh"
        mo.target === nothing && return
        face_target(mo, mo.target)
        play(game, "skeswg")
    elseif name == "SkelFist"
        mo.target === nothing && return
        face_target(mo, mo.target)
        dist = approx_distance(mo.target.x - mo.x, mo.target.y - mo.y)
        if dist < MELEERANGE + mo.radius
            play(game, "skepch")
            game.damage_mobj(mo.target, mo, ((p_random() % 8) + 1) * 6)
        end
    elseif name == "SkelMissile"
        mo.target === nothing && return
        face_target(mo, mo.target)
        miss = spawn_missile_mt(world, mo, mo.target, MT_TRACER, game)
        miss.tracer = mo.target
        miss.z += 16 * FRACUNIT
    elseif name == "FatRaise"
        mo.target !== nothing && face_target(mo, mo.target)
        play(game, "manatk")
    elseif name == "FatAttack1"
        mo.target === nothing && return
        face_target(mo, mo.target)
        mo.angle = as_u32(Int64(mo.angle) + FATSPREAD)
        spawn_missile_mt(world, mo, mo.target, MT_FATSHOT, game)
        miss = spawn_missile_mt(world, mo, mo.target, MT_FATSHOT, game)
        miss.angle = as_u32(Int64(miss.angle) + FATSPREAD)
        miss.momx = Int(fixed_mul(mi(miss).speed, fine_cos(miss.angle)))
        miss.momy = Int(fixed_mul(mi(miss).speed, fine_sin(miss.angle)))
    elseif name == "FatAttack2"
        mo.target === nothing && return
        face_target(mo, mo.target)
        mo.angle = as_u32(Int64(mo.angle) - FATSPREAD)
        spawn_missile_mt(world, mo, mo.target, MT_FATSHOT, game)
        miss = spawn_missile_mt(world, mo, mo.target, MT_FATSHOT, game)
        miss.angle = as_u32(Int64(miss.angle) - FATSPREAD * 2)
        miss.momx = Int(fixed_mul(mi(miss).speed, fine_cos(miss.angle)))
        miss.momy = Int(fixed_mul(mi(miss).speed, fine_sin(miss.angle)))
    elseif name == "FatAttack3"
        mo.target === nothing && return
        face_target(mo, mo.target)
        miss = spawn_missile_mt(world, mo, mo.target, MT_FATSHOT, game)
        miss.angle = as_u32(Int64(mo.angle) - fld(FATSPREAD, 2))
        miss.momx = Int(fixed_mul(mi(miss).speed, fine_cos(miss.angle)))
        miss.momy = Int(fixed_mul(mi(miss).speed, fine_sin(miss.angle)))
        miss = spawn_missile_mt(world, mo, mo.target, MT_FATSHOT, game)
        miss.angle = as_u32(Int64(mo.angle) + fld(FATSPREAD, 2))
        miss.momx = Int(fixed_mul(mi(miss).speed, fine_cos(miss.angle)))
        miss.momy = Int(fixed_mul(mi(miss).speed, fine_sin(miss.angle)))
    elseif name == "BrainPain"
        play(game, "bospn")
    elseif name == "BrainScream"
        play(game, "bosdth")
    elseif name == "BrainDie"
        game.specials !== nothing && (game.specials.exit_requested = true)
    elseif name == "BrainAwake"
        empty!(brain_targets)
        for th in world.mobjs
            th.typ == MT_BOSSTARGET && push!(brain_targets, th)
        end
        brain_target_on = 0
        play(game, "bossit")
    elseif name == "BrainSpit"
        if game.skill <= SK_EASY
            mo.easy_skip = !mo.easy_skip
            mo.easy_skip && return
        end
        targs = brain_targets
        if isempty(targs)
            for th in world.mobjs
                th.typ == MT_BOSSTARGET && push!(targs, th)
            end
        end
        isempty(targs) && return
        dest = targs[mod(brain_target_on, length(targs)) + 1]
        brain_target_on += 1
        play(game, "bospit")
        miss = spawn_missile_mt(world, mo, dest, MT_SPAWNSHOT, game)
        miss.target = dest
        st = miss.tics == 0 ? 1 : miss.tics
        if miss.momy != 0
            miss.reactiontime = fld(fld(dest.y - mo.y, miss.momy), st)
        end
    elseif name == "SpawnSound"
        play(game, "boscub")
        mo.reactiontime -= 1
        mo.reactiontime == 0 && spawn_fly(world, mo, game)
    elseif name == "SpawnFly"
        mo.reactiontime -= 1
        mo.reactiontime == 0 && spawn_fly(world, mo, game)
    elseif name == "BFGSpray"
        bfg_spray(world, mo, game)
    elseif name == "PlayerScream"
        play(game, "pldeth")
    end
    nothing
end

Thinker.act![] = call_action

end

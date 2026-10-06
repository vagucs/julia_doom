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
# Estado das coisas, a partir de thinker.py.

module Thinker

using ..Compat
using ..Collision
using ..Info
using ..Rng
using ..Tables
using ..Sprites
using ..Player

export spawn_mobj!, remove_mobj!, set_mobj_state!, spawn_map!, tick_actors!, apply_fast!
export ONFLOORZ, ONCEILINGZ

const FRACUNIT = 65536
const MF_CORPSE = 1048576
const MF_COUNTKILL = 4194304
const MF_COUNTITEM = 8388608
const MF_MISSILE = 65536
const MF_SKULLFLY = 16777216
const MF_SPAWNCEILING = 256
const MF_AMBUSH = 32
const MTF_AMBUSH = 8
const SK_NIGHTMARE = 4
const TICRATE = 35
const S_NULL = 0
const ONFLOORZ = -2147483648
const ONCEILINGZ = 2147483647

const act! = Ref{Any}(nothing)
fast_on = nothing
sarg_saved = Int[]
shot_saved = Dict{Int,Int}()

has(flags, bit) = band(flags, bit) != 0

function skill_bit(skill)
    skill <= 1 && return 1
    skill >= 3 && return 4
    2
end

function spawn_mobj!(world, x, y, z, typ, game)
    row = info_at(typ)
    sub = point_in_subsector(world, x, y)
    mo = new_mobj(
        x=x, y=y, z=0, radius=row.radius, height=row.height,
        floorz=Int(sub.sector.floorheight), ceilingz=Int(sub.sector.ceilingheight),
        flags=row.flags, health=row.spawnhealth, typ=typ, doomednum=row.doomednum,
        damage=row.damage, movedir=8,
    )
    if game !== nothing && game.skill != SK_NIGHTMARE
        mo.reactiontime = row.reactiontime
    end
    mo.lastlook = p_random() % 4
    if z == ONCEILINGZ || (has(row.flags, MF_SPAWNCEILING) && z == ONFLOORZ)
        mo.z = mo.ceilingz - mo.height
    elseif z == ONFLOORZ
        mo.z = mo.floorz
    else
        mo.z = z
    end
    push!(world.mobjs, mo)
    set_thing_position!(world, mo)
    set_mobj_state!(mo, row.spawnstate, world, game)
    mo
end

function remove_mobj!(world, mo)
    unset_thing_position!(world, mo)
    mo.alive = false
    mo.istate = S_NULL
    mo.flags = 0
    mo.sprite = ""
    i = findfirst(x -> x === mo, world.mobjs)
    i !== nothing && deleteat!(world.mobjs, i)
    nothing
end

function set_mobj_state!(mo, state, world, game)
    safety = 0
    while true
        if state == S_NULL || mo === nothing
            if mo !== nothing && world !== nothing
                remove_mobj!(world, mo)
            end
            return false
        end
        st = state_at(state)
        mo.istate = state
        mo.tics = st.tics
        mo.sprite = spr_name(st.sprite)
        mo.frame = st.frame
        name = action_name(st.action)
        if name != "" && act![] !== nothing
            act![](name, mo, world, game)
            mo.alive == false && return false
        end
        state = st.nxt
        mo.tics != 0 && return true
        safety += 1
        safety > 100 && return true
    end
end

function mobj_thinker!(world, mo, game)
    if mo.momx != 0 || mo.momy != 0 || has(mo.flags, MF_SKULLFLY)
        Main.Enemy.p_xy_movement(world, mo, game)
        mo.alive == false && return
    end
    if mo.z != mo.floorz || mo.momz != 0
        Main.Enemy.mobj_z(mo, world, game)
        mo.alive == false && return
    end
    if mo.tics != -1
        mo.tics -= 1
        if mo.tics <= 0
            set_mobj_state!(mo, state_at(mo.istate).nxt, world, game)
        end
        return
    end
    has(mo.flags, MF_COUNTKILL) || return
    game.respawnmonsters || return
    mo.movecount += 1
    mo.movecount < 12 * TICRATE && return
    band(game.leveltime, 31) != 0 && return
    Main.Enemy.p_random() > 4 && return
    nightmare_respawn!(world, mo, game)
    nothing
end

function nightmare_respawn!(world, mo, game)
    sp = mo.spawnpoint
    sp === nothing && return
    x, y = sp.x * FRACUNIT, sp.y * FRACUNIT
    check_position(world, mo, x, y, nothing).blocked && return
    row = info_at(mo.typ)
    spawn_mobj!(world, mo.x, mo.y, mo.floorz, MT_TFOG, game)
    game !== nothing && game.start_sound !== nothing && game.start_sound("telept")
    sub = point_in_subsector(world, x, y)
    spawn_mobj!(world, x, y, Int(sub.sector.floorheight), MT_TFOG, game)
    game !== nothing && game.start_sound !== nothing && game.start_sound("telept")
    z = has(row.flags, MF_SPAWNCEILING) ? ONCEILINGZ : ONFLOORZ
    spawned = spawn_mobj!(world, x, y, z, mo.typ, game)
    spawned.spawnpoint = sp
    spawned.angle = as_u32(fld(sp.angle, 45) * 536870912)
    if band(sp.options, MTF_AMBUSH) != 0
        spawned.flags = Int(bor(spawned.flags, MF_AMBUSH))
    end
    spawned.reactiontime = 18
    remove_mobj!(world, mo)
    nothing
end

function apply_fast!(game)
    global fast_on, sarg_saved, shot_saved
    want = game.fastparm == true || game.skill == SK_NIGHTMARE
    game.respawnmonsters = game.skill == SK_NIGHTMARE || game.respawnparm == true
    fast_on == want && return
    if isempty(sarg_saved)
        for i in S_SARG_RUN1:S_SARG_PAIN2
            push!(sarg_saved, state_at(i).tics)
        end
        shot_saved[MT_BRUISERSHOT] = info_at(MT_BRUISERSHOT).speed
        shot_saved[MT_HEADSHOT] = info_at(MT_HEADSHOT).speed
        shot_saved[MT_TROOPSHOT] = info_at(MT_TROOPSHOT).speed
    end
    fast_on = want
    n = 0
    for i in S_SARG_RUN1:S_SARG_PAIN2
        n += 1
        tics = sarg_saved[n]
        want && (tics = max(1, fld(tics, 2)))
        state_at(i).tics = tics
    end
    fast = 20 * FRACUNIT
    for (mt, spd) in shot_saved
        info_at(mt).speed = want ? fast : spd
    end
    nothing
end

function spawn_map!(world, skill, game)
    init_tables!()
    bit = skill_bit(skill)
    kills, items = 0, 0
    empty!(world.mobjs)
    nomonsters = game !== nothing && game.nomonsters == true
    for mt in world.things
        typ = mt.type
        typ == 11 && continue
        if typ == 1 || typ == 2 || typ == 3 || typ == 4
            if typ == 1 && game !== nothing && game.player === nothing
                game.player = spawn_player(world, mt, 0)
            end
        elseif band(mt.options, bit) != 0 && band(mt.options, 16) == 0
            mt_type = mobj_type_for_doomednum(typ)
            mt_type < 0 && continue
            flags = info_at(mt_type).flags
            skip = nomonsters && (has(flags, MF_COUNTKILL) || mt_type == MT_SKULL)
            skip && continue
            z = has(flags, MF_SPAWNCEILING) ? ONCEILINGZ : ONFLOORZ
            mo = spawn_mobj!(world, mt.x * FRACUNIT, mt.y * FRACUNIT, z, mt_type, game)
            if mo.tics > 0
                mo.tics = 1 + (p_random() % mo.tics)
            end
            mo.angle = as_u32(fld(mt.angle, 45) * 536870912)
            mo.spawnpoint = mt
            if band(mt.options, MTF_AMBUSH) != 0
                mo.flags = Int(bor(mo.flags, MF_AMBUSH))
            end
            has(mo.flags, MF_COUNTKILL) && (kills += 1)
            has(mo.flags, MF_COUNTITEM) && (items += 1)
        end
    end
    kills, items
end

function tick_actors!(world, game)
    player = game.player
    (player === nothing || player.mo === nothing) && return
    list = copy(world.mobjs)
    for mo in list
        (mo === player.mo || mo.fx) && continue
        mo.alive == false && continue
        mobj_thinker!(world, mo, game)
    end
    nothing
end

end

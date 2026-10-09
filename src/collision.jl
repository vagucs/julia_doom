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
# Colisao, uso e tiro, a partir de collision.py.
# O bloco do mapa continua 0-based na conta e soma 1 no vetor.

module Collision

using ..Compat
using ..World
using ..Tables
using ..Rng
using ..Sprites

export link_mobjs!, set_thing_position!, unset_thing_position!
export try_move!, slide_move!, use_lines!, line_attack!, bullet_slope
export point_on_line_side, point_in_subsector, line_opening, angle_to, approx_distance
export change_sector!, check_sight, aim_slope, aim_line_attack

const FRACBITS = 16
const FRACUNIT = 65536
const ANG90 = 1073741824
const ANG180 = Int64(2147483648)
const BOXLEFT = 1
const BOXRIGHT = 2
const BOXBOTTOM = 3
const BOXTOP = 4
const MAXMOVE = 30 * FRACUNIT
const MAPBLOCKSHIFT = 23
const MAPBLOCKSIZE = 128 * FRACUNIT
const MAPBTOFRAC = MAPBLOCKSHIFT - FRACBITS
const MAXRADIUS = 32 * FRACUNIT
const USERANGE = 64 * FRACUNIT
const MELEERANGE = 64 * FRACUNIT
const MAXSTEP = 24 * FRACUNIT
const PT_ADDLINES = 1
const PT_ADDTHINGS = 2
const PT_EARLYOUT = 4
const MF_SPECIAL = 1
const MF_SOLID = 2
const MF_SHOOTABLE = 4
const MF_NOBLOCKMAP = 16
const MF_MISSILE = 65536
const MF_NOBLOOD = 524288
const MF_SKULLFLY = 16777216
const MF_FLOAT = 16384
const MF_DROPOFF = 1024
const MF_PICKUP = 2048
const MF_NOCLIP = 4096
const MF_TELEPORT = 32768
const ML_BLOCKING = 1
const ML_BLOCKMONSTERS = 2
const ML_TWOSIDED = 4
const INT_MAX = 2147483647
const MT_PLAYER = 0
const MT_BRUISER = 15
const MT_KNIGHT = 17

has(flags, bit) = band(flags, bit) != 0

function abs32(n)
    n = Int(as_i32(n))
    n < 0 ? -n : n
end

point_in_subsector(world, x, y) = World.point_in_subsector(world, x, y)

function point_on_line_side(x, y, line)
    if line.dx == 0
        if x <= line.v1.x
            return line.dy > 0 ? 1 : 0
        end
        return line.dy < 0 ? 1 : 0
    end
    if line.dy == 0
        if y <= line.v1.y
            return line.dx < 0 ? 1 : 0
        end
        return line.dx > 0 ? 1 : 0
    end
    dx = Int(as_i32(Int(x) - Int(line.v1.x)))
    dy = Int(as_i32(Int(y) - Int(line.v1.y)))
    left = Int(fixed_mul(shar(line.dy, FRACBITS), dx))
    right = Int(fixed_mul(dy, shar(line.dx, FRACBITS)))
    right < left ? 0 : 1
end

function box_on_line_side(bbox, line)
    p1 = 0
    p2 = 0
    if line.dx == 0
        bbox[BOXRIGHT] >= line.v1.x && (p1 = 1)
        bbox[BOXLEFT] >= line.v1.x && (p2 = 1)
        if line.dy > 0
            p1 = Int(bxor(p1, 1))
            p2 = Int(bxor(p2, 1))
        end
    elseif line.dy == 0
        bbox[BOXTOP] <= line.v1.y && (p1 = 1)
        bbox[BOXBOTTOM] <= line.v1.y && (p2 = 1)
        if line.dx < 0
            p1 = Int(bxor(p1, 1))
            p2 = Int(bxor(p2, 1))
        end
    else
        slope = (line.dy > 0) == (line.dx > 0) ? 0 : 1
        if slope == 0
            p1 = point_on_line_side(bbox[BOXLEFT], bbox[BOXTOP], line)
            p2 = point_on_line_side(bbox[BOXRIGHT], bbox[BOXBOTTOM], line)
        else
            p1 = point_on_line_side(bbox[BOXRIGHT], bbox[BOXTOP], line)
            p2 = point_on_line_side(bbox[BOXLEFT], bbox[BOXBOTTOM], line)
        end
    end
    p1 == p2 ? p1 : -1
end

function line_opening(line)
    line.backsector === nothing && return 0, 0, 0
    front, back = line.frontsector, line.backsector
    opentop = min(Int(front.ceilingheight), Int(back.ceilingheight))
    if Int(front.floorheight) > Int(back.floorheight)
        return opentop, Int(front.floorheight), Int(back.floorheight)
    end
    opentop, Int(back.floorheight), Int(front.floorheight)
end

function approx_distance(dx, dy)
    dx, dy = abs(Int(dx)), abs(Int(dy))
    dx < dy && ((dx, dy) = (dy, dx))
    dx + fld(dy, 2)
end

function angle_to(x1, y1, x2, y2)
    init_tables!()
    x = Int(as_i32(Int(x2) - Int(x1)))
    y = Int(as_i32(Int(y2) - Int(y1)))
    x == 0 && y == 0 && return UInt32(0)
    if x >= 0
        if y >= 0
            x > y && return tanto_at(slope_div(y, x))
            return as_u32(ANG90 - 1 - Int64(tanto_at(slope_div(x, y))))
        end
        y = -y
        x > y && return as_u32(-Int64(tanto_at(slope_div(y, x))))
        return as_u32(3221225472 + Int64(tanto_at(slope_div(x, y))))
    end
    x = -x
    if y >= 0
        x > y && return as_u32(ANG180 - 1 - Int64(tanto_at(slope_div(y, x))))
        return as_u32(ANG90 + Int64(tanto_at(slope_div(x, y))))
    end
    y = -y
    x > y && return as_u32(ANG180 + Int64(tanto_at(slope_div(y, x))))
    as_u32(3221225472 - 1 - Int64(tanto_at(slope_div(x, y))))
end

function unset_thing_position!(world, thing)
    thing.blocklinked || return
    nxt = thing.bnext
    prev = thing.bprev
    nxt !== nothing && (nxt.bprev = prev)
    if prev !== nothing
        prev.bnext = nxt
    else
        i = thing.bindex
        links = world.blocklinks
        if 1 <= i <= length(links) && links[i] === thing
            links[i] = nxt
        end
    end
    thing.bnext = nothing
    thing.bprev = nothing
    thing.blocklinked = false
    nothing
end

function set_thing_position!(world, thing)
    thing.blocklinked && unset_thing_position!(world, thing)
    links = world.blocklinks
    thing.bnext = nothing
    thing.bprev = nothing
    thing.blocklinked = false
    (has(thing.flags, MF_NOBLOCKMAP) || world.bmapwidth == 0) && return
    bx = Int(shar(Int(thing.x) - Int(world.bmaporgx), MAPBLOCKSHIFT))
    by = Int(shar(Int(thing.y) - Int(world.bmaporgy), MAPBLOCKSHIFT))
    (bx < 0 || by < 0 || bx >= world.bmapwidth || by >= world.bmapheight) && return
    i = by * world.bmapwidth + bx + 1
    head = links[i]
    thing.bnext = head
    head !== nothing && (head.bprev = thing)
    links[i] = thing
    thing.bindex = i
    thing.blocklinked = true
    nothing
end

function link_mobjs!(world)
    for mo in world.mobjs
        set_thing_position!(world, mo)
    end
    world
end

function block_things(world, x, y, func)
    (x < 0 || y < 0 || x >= world.bmapwidth || y >= world.bmapheight) && return true
    mo = world.blocklinks[y * world.bmapwidth + x + 1]
    while mo !== nothing
        nxt = mo.bnext
        func(mo) || return false
        mo = nxt
    end
    true
end

function block_lines(world, x, y, func)
    (x < 0 || y < 0 || x >= world.bmapwidth || y >= world.bmapheight) && return true
    lump = world.blockmaplump
    offset = world.blockmap[y * world.bmapwidth + x + 1]
    nlines = length(world.lines)
    while offset >= 0 && offset < length(lump)
        n = lump[offset + 1]
        offset += 1
        n == 65535 && return true
        if 0 <= n < nlines
            ld = world.lines[n + 1]
            if ld.validcount != world.validcount
                ld.validcount = world.validcount
                func(ld) || return false
            end
        end
    end
    true
end

function same_species(target, other)
    target.typ == other.typ && return true
    target.typ == MT_KNIGHT && other.typ == MT_BRUISER && return true
    target.typ == MT_BRUISER && other.typ == MT_KNIGHT
end

function call_damage(game, target, source, damage, inflictor)
    (game === nothing || game.damage_mobj === nothing) && return
    game.damage_mobj(target, source, damage, inflictor)
    nothing
end

function pit_thing(world, tm, other, game)
    has(other.flags, MF_SOLID + MF_SPECIAL + MF_SHOOTABLE) || return true
    blockdist = other.radius + tm.radius
    (abs(other.x - tm.tmx) >= blockdist || abs(other.y - tm.tmy) >= blockdist) && return true
    other === tm && return true
    if has(tm.flags, MF_SKULLFLY)
        dmg = ((p_random() % 8) + 1) * tm.damage
        call_damage(game, other, tm, dmg, tm)
        tm.flags = Int(band(tm.flags, bnot(MF_SKULLFLY)))
        tm.momx = 0
        tm.momy = 0
        tm.momz = 0
        return false
    end
        if has(tm.flags, MF_MISSILE)
            target = tm.target
            if target !== nothing && same_species(target, other)
                other === target && return true
                other.typ != MT_PLAYER && return false
            end
            if !has(other.flags, MF_SHOOTABLE)
                return !has(other.flags, MF_SOLID)
            end
            missile_reaches(tm, other, tm.tmx, tm.tmy, tm.z) || return true
            tm.struck = other
            return false
        end
    if has(other.flags, MF_SPECIAL)
        solid = has(other.flags, MF_SOLID)
        if has(tm.flags, MF_PICKUP) && game !== nothing && game.touch_special !== nothing
            game.touch_special(other, tm)
        end
        return !solid
    end
    !has(other.flags, MF_SOLID)
end

mutable struct Check
    floorz::Int
    ceilingz::Int
    dropoffz::Int
    spechit::Vector{Any}
    blocked::Bool
    ceilingline::Any
    bbox::Vector{Int}
end

function pit_line(tm, chk, ld)
    bbox = chk.bbox
    lb = ld.bbox
    if bbox[BOXRIGHT] <= lb[BOXLEFT] || bbox[BOXLEFT] >= lb[BOXRIGHT] ||
       bbox[BOXTOP] <= lb[BOXBOTTOM] || bbox[BOXBOTTOM] >= lb[BOXTOP]
        return true
    end
    box_on_line_side(bbox, ld) != -1 && return true
    ld.backsector === nothing && return false
    if !has(tm.flags, MF_MISSILE)
        has(ld.flags, ML_BLOCKING) && return false
        tm.player === nothing && has(ld.flags, ML_BLOCKMONSTERS) && return false
    end
    opentop, openbottom, lowfloor = line_opening(ld)
    if opentop < chk.ceilingz
        chk.ceilingz = opentop
        chk.ceilingline = ld
    end
    openbottom > chk.floorz && (chk.floorz = openbottom)
    lowfloor < chk.dropoffz && (chk.dropoffz = lowfloor)
    ld.special != 0 && push!(chk.spechit, ld)
    true
end

function check_position(world, thing, x, y, game)
    chk = Check(0, 0, 0, Any[], false, nothing, zeros(Int, 4))
    thing.tmx = x
    thing.tmy = y
    radius = thing.radius
    bbox = chk.bbox
    bbox[BOXTOP] = y + radius
    bbox[BOXBOTTOM] = y - radius
    bbox[BOXRIGHT] = x + radius
    bbox[BOXLEFT] = x - radius
    sub = point_in_subsector(world, x, y)
    chk.floorz = Int(sub.sector.floorheight)
    chk.dropoffz = chk.floorz
    chk.ceilingz = Int(sub.sector.ceilingheight)
    world.validcount += 1
    has(thing.flags, MF_NOCLIP) && return chk
    world.bmapwidth == 0 && return chk
    orgx, orgy = Int(world.bmaporgx), Int(world.bmaporgy)
    xl = Int(shar(bbox[BOXLEFT] - orgx - MAXRADIUS, MAPBLOCKSHIFT))
    xh = Int(shar(bbox[BOXRIGHT] - orgx + MAXRADIUS, MAPBLOCKSHIFT))
    yl = Int(shar(bbox[BOXBOTTOM] - orgy - MAXRADIUS, MAPBLOCKSHIFT))
    yh = Int(shar(bbox[BOXTOP] - orgy + MAXRADIUS, MAPBLOCKSHIFT))
    for bx in xl:xh, by in yl:yh
        if !block_things(world, bx, by, th -> pit_thing(world, thing, th, game))
            chk.blocked = true
            return chk
        end
    end
    xl = Int(shar(bbox[BOXLEFT] - orgx, MAPBLOCKSHIFT))
    xh = Int(shar(bbox[BOXRIGHT] - orgx, MAPBLOCKSHIFT))
    yl = Int(shar(bbox[BOXBOTTOM] - orgy, MAPBLOCKSHIFT))
    yh = Int(shar(bbox[BOXTOP] - orgy, MAPBLOCKSHIFT))
    for bx in xl:xh, by in yl:yh
        if !block_lines(world, bx, by, ld -> pit_line(thing, chk, ld))
            chk.blocked = true
            return chk
        end
    end
    chk
end

floatok = false
tmfloorz = 0
last_spechit = Any[]
ceilingline = nothing

function try_move!(world, thing, x, y, game)
    global floatok, tmfloorz, last_spechit, ceilingline
    floatok = false
    ceilingline = nothing
    chk = check_position(world, thing, x, y, game)
    last_spechit = chk.spechit
    tmfloorz = chk.floorz
    ceilingline = chk.ceilingline
    chk.blocked && return false
    if !has(thing.flags, MF_NOCLIP)
        chk.ceilingz - chk.floorz < thing.height && return false
        floatok = true
        if !has(thing.flags, MF_TELEPORT) && chk.ceilingz - thing.z < thing.height
            return false
        end
        if !has(thing.flags, MF_TELEPORT) && chk.floorz - thing.z > MAXSTEP
            return false
        end
        if !has(thing.flags, MF_DROPOFF + MF_FLOAT) && chk.floorz - chk.dropoffz > MAXSTEP
            return false
        end
    end
    unset_thing_position!(world, thing)
    oldx, oldy = thing.x, thing.y
    thing.floorz = chk.floorz
    thing.ceilingz = chk.ceilingz
    thing.x = x
    thing.y = y
    set_thing_position!(world, thing)
    if game !== nothing && !has(thing.flags, MF_TELEPORT + MF_NOCLIP) && game.cross_special !== nothing
        for i in length(chk.spechit):-1:1
            ln = chk.spechit[i]
            side = point_on_line_side(thing.x, thing.y, ln)
            oldside = point_on_line_side(oldx, oldy, ln)
            if side != oldside && ln.special != 0
                game.cross_special(ln, oldside, thing)
            end
        end
    end
    true
end

mutable struct Trace
    x::Int
    y::Int
    dx::Int
    dy::Int
end

mutable struct Intercept
    frac::Int
    isaline::Bool
    line::Any
    thing::Any
end

const trace = Trace(0, 0, 0, 0)
earlyout = false
intercepts = Intercept[]

function point_on_divline_side(x, y, line)
    if line.dx == 0
        if x <= line.x
            return line.dy > 0 ? 1 : 0
        end
        return line.dy < 0 ? 1 : 0
    end
    if line.dy == 0
        if y <= line.y
            return line.dx < 0 ? 1 : 0
        end
        return line.dx > 0 ? 1 : 0
    end
    dx = Int(x) - Int(line.x)
    dy = Int(y) - Int(line.y)
    xorv = bxor(bxor(bxor(as_u32(line.dy), as_u32(line.dx)), as_u32(dx)), as_u32(dy))
    if band(xorv, 2147483648) != 0
        return band(bxor(as_u32(line.dy), as_u32(dx)), 2147483648) != 0 ? 1 : 0
    end
    left = Int(fixed_mul(shar(line.dy, 8), shar(dx, 8)))
    right = Int(fixed_mul(shar(dy, 8), shar(line.dx, 8)))
    right < left ? 0 : 1
end

function intercept_vector(v2, v1)
    den = Int(as_i32(Int(fixed_mul(shar(v1.dy, 8), v2.dx)) - Int(fixed_mul(shar(v1.dx, 8), v2.dy))))
    den == 0 && return 0
    num = Int(as_i32(Int(fixed_mul(shar(Int(v1.x) - Int(v2.x), 8), v1.dy)) + Int(fixed_mul(shar(Int(v2.y) - Int(v1.y), 8), v1.dx))))
    Int(fixed_div(num, den))
end

function add_line_intercept(ld)
    big = 16 * FRACUNIT
    dx, dy = trace.dx, trace.dy
    if dx > big || dy > big || dx < -big || dy < -big
        s1 = point_on_divline_side(ld.v1.x, ld.v1.y, trace)
        s2 = point_on_divline_side(ld.v2.x, ld.v2.y, trace)
    else
        s1 = point_on_line_side(trace.x, trace.y, ld)
        s2 = point_on_line_side(trace.x + dx, trace.y + dy, ld)
    end
    s1 == s2 && return true
    frac = intercept_vector(trace, (x=ld.v1.x, y=ld.v1.y, dx=ld.dx, dy=ld.dy))
    frac < 0 && return true
    if earlyout && frac < FRACUNIT && ld.backsector === nothing
        return false
    end
    push!(intercepts, Intercept(frac, true, ld, nothing))
    true
end

function add_thing_intercept(thing)
    positive = Int(as_i32(bxor(as_u32(trace.dx), as_u32(trace.dy)))) > 0
    radius = thing.radius
    if positive
        x1, y1 = thing.x - radius, thing.y + radius
        x2, y2 = thing.x + radius, thing.y - radius
    else
        x1, y1 = thing.x - radius, thing.y - radius
        x2, y2 = thing.x + radius, thing.y + radius
    end
    point_on_divline_side(x1, y1, trace) == point_on_divline_side(x2, y2, trace) && return true
    frac = intercept_vector(trace, (x=x1, y=y1, dx=x2 - x1, dy=y2 - y1))
    frac < 0 && return true
    push!(intercepts, Intercept(frac, false, nothing, thing))
    true
end

function traverse_intercepts(func, maxfrac)
    count = length(intercepts)
    while count > 0
        count -= 1
        dist = INT_MAX
        chosen = nothing
        for scan in intercepts
            if scan.frac < dist
                dist = scan.frac
                chosen = scan
            end
        end
        dist > maxfrac && return true
        (chosen === nothing || !func(chosen)) && return false
        chosen.frac = INT_MAX
    end
    true
end

function path_traverse(world, x1, y1, x2, y2, flags, trav)
    global earlyout
    earlyout = band(flags, PT_EARLYOUT) != 0
    world.validcount += 1
    empty!(intercepts)
    orgx, orgy = Int(world.bmaporgx), Int(world.bmaporgy)
    band(as_i32(Int(x1) - orgx), MAPBLOCKSIZE - 1) == 0 && (x1 += FRACUNIT)
    band(as_i32(Int(y1) - orgy), MAPBLOCKSIZE - 1) == 0 && (y1 += FRACUNIT)
    trace.x = x1
    trace.y = y1
    trace.dx = Int(as_i32(Int(x2) - Int(x1)))
    trace.dy = Int(as_i32(Int(y2) - Int(y1)))
    x1m = Int(as_i32(Int(x1) - orgx))
    y1m = Int(as_i32(Int(y1) - orgy))
    xt1 = Int(shar(x1m, MAPBLOCKSHIFT))
    yt1 = Int(shar(y1m, MAPBLOCKSHIFT))
    x2m = Int(as_i32(Int(x2) - orgx))
    y2m = Int(as_i32(Int(y2) - orgy))
    xt2 = Int(shar(x2m, MAPBLOCKSHIFT))
    yt2 = Int(shar(y2m, MAPBLOCKSHIFT))
    mapxstep = 0
    mapystep = 0
    partial = FRACUNIT
    ystep = 256 * FRACUNIT
    xstep = 256 * FRACUNIT
    if xt2 > xt1
        mapxstep = 1
        partial = FRACUNIT - Int(band(shar(x1m, MAPBTOFRAC), FRACUNIT - 1))
        ystep = Int(fixed_div(as_i32(y2m - y1m), abs32(as_i32(x2m - x1m))))
    elseif xt2 < xt1
        mapxstep = -1
        partial = Int(band(shar(x1m, MAPBTOFRAC), FRACUNIT - 1))
        ystep = Int(fixed_div(as_i32(y2m - y1m), abs32(as_i32(x2m - x1m))))
    end
    yintercept = Int(as_i32(Int(shar(y1m, MAPBTOFRAC)) + Int(fixed_mul(partial, ystep))))
    if yt2 > yt1
        mapystep = 1
        partial = FRACUNIT - Int(band(shar(y1m, MAPBTOFRAC), FRACUNIT - 1))
        xstep = Int(fixed_div(as_i32(x2m - x1m), abs32(as_i32(y2m - y1m))))
    elseif yt2 < yt1
        mapystep = -1
        partial = Int(band(shar(y1m, MAPBTOFRAC), FRACUNIT - 1))
        xstep = Int(fixed_div(as_i32(x2m - x1m), abs32(as_i32(y2m - y1m))))
    end
    xintercept = Int(as_i32(Int(shar(x1m, MAPBTOFRAC)) + Int(fixed_mul(partial, xstep))))
    mapx, mapy = xt1, yt1
    for _ in 1:64
        if band(flags, PT_ADDLINES) != 0
            block_lines(world, mapx, mapy, add_line_intercept) || return false
        end
        if band(flags, PT_ADDTHINGS) != 0
            block_things(world, mapx, mapy, add_thing_intercept) || return false
        end
        (mapx == xt2 && mapy == yt2) && break
        if Int(shar(yintercept, FRACBITS)) == mapy
            yintercept = Int(as_i32(yintercept + ystep))
            mapx += mapxstep
        elseif Int(shar(xintercept, FRACBITS)) == mapx
            xintercept = Int(as_i32(xintercept + xstep))
            mapy += mapystep
        end
    end
    traverse_intercepts(trav, FRACUNIT)
end

function stairstep!(world, thing, game)
    try_move!(world, thing, thing.x, thing.y + thing.momy, game) ||
        try_move!(world, thing, thing.x + thing.momx, thing.y, game)
    nothing
end

function missile_reaches(mo, other, x, y, z)
    (other === mo || other === mo.target || other.health <= 0) && return false
    has(other.flags, MF_SHOOTABLE) || return false
    reach = other.radius + mo.radius
    (abs(other.x - x) >= reach || abs(other.y - y) >= reach) && return false
    slack = 64 * FRACUNIT
    z1 = z + mo.momz
    low = min(z, z1) - slack
    high = max(z, z1) + mo.height + slack
    if z <= mo.floorz
        low = min(low, mo.floorz - slack)
        high = max(high, mo.floorz + slack)
    end
    low <= other.z + other.height && high >= other.z
end

mutable struct SlideBest
    frac::Int
    line::Any
end

function slide_blocks(thing, li)
    if !has(li.flags, ML_TWOSIDED) || li.backsector === nothing || li.frontsector === nothing
        return point_on_line_side(thing.x, thing.y, li) == 0
    end
    opentop, openbottom, _ = line_opening(li)
    opentop - openbottom < thing.height && return true
    opentop - thing.z < thing.height && return true
    openbottom - thing.z > 24 * FRACUNIT && return true
    has(li.flags, ML_BLOCKING)
end

function intercept_frac(x1, y1, x2, y2, line)
    u = Float64(FRACUNIT)
    ax, ay = x1 / u, y1 / u
    bx, by = x2 / u, y2 / u
    cx, cy = Float64(line.v1.x) / u, Float64(line.v1.y) / u
    dx, dy = Float64(line.v2.x) / u, Float64(line.v2.y) / u
    den = (bx - ax) * (dy - cy) - (by - ay) * (dx - cx)
    abs(den) < 1e-8 && return nothing
    t = ((cx - ax) * (dy - cy) - (cy - ay) * (dx - cx)) / den
    v = ((cx - ax) * (by - ay) - (cy - ay) * (bx - ax)) / den
    (t < 0 || t > 1 || v < 0 || v > 1) && return nothing
    Int(trunc(t * u))
end

function trace_slide_corner!(world, thing, x1, y1, x2, y2, best)
    for ln in world.lines
        frac = intercept_frac(x1, y1, x2, y2, ln)
        (frac === nothing || frac < 0 || frac > FRACUNIT || !slide_blocks(thing, ln)) && continue
        if frac < best.frac
            best.frac = frac
            best.line = ln
        end
    end
    nothing
end

function hit_slide_line(thing, line, tmx, tmy)
    line.dy == 0 && return tmx, 0
    line.dx == 0 && return 0, tmy
    side = point_on_line_side(thing.x, thing.y, line)
    lineangle = angle_to(0, 0, line.dx, line.dy)
    side == 1 && (lineangle = as_u32(Int64(lineangle) + ANG180))
    moveangle = angle_to(0, 0, tmx, tmy)
    delta = as_u32(Int64(moveangle) - Int64(lineangle))
    if delta > ANG180
        delta = as_u32(Int64(delta) + ANG180)
    end
    newlen = Int(fixed_mul(approx_distance(tmx, tmy), fine_cos(delta)))
    Int(fixed_mul(newlen, fine_cos(lineangle))), Int(fixed_mul(newlen, fine_sin(lineangle)))
end

function slide_move!(world, thing, momx, momy, game)
    if abs(momx) > MAXMOVE
        momx = momx > 0 ? MAXMOVE : -MAXMOVE
    end
    if abs(momy) > MAXMOVE
        momy = momy > 0 ? MAXMOVE : -MAXMOVE
    end
    thing.momx = momx
    thing.momy = momy
    hitcount = 0
    while true
        hitcount += 1
        if hitcount == 3
            stairstep!(world, thing, game)
            return
        end
        if thing.momx > 0
            leadx = thing.x + thing.radius
            trailx = thing.x - thing.radius
        else
            leadx = thing.x - thing.radius
            trailx = thing.x + thing.radius
        end
        if thing.momy > 0
            leady = thing.y + thing.radius
            traily = thing.y - thing.radius
        else
            leady = thing.y - thing.radius
            traily = thing.y + thing.radius
        end
        best = SlideBest(FRACUNIT + 1, nothing)
        mx, my = thing.momx, thing.momy
        trace_slide_corner!(world, thing, leadx, leady, leadx + mx, leady + my, best)
        trace_slide_corner!(world, thing, trailx, leady, trailx + mx, leady + my, best)
        trace_slide_corner!(world, thing, leadx, traily, leadx + mx, traily + my, best)
        if best.frac == FRACUNIT + 1 || best.line === nothing
            stairstep!(world, thing, game)
            return
        end
        best.frac -= 2048
        if best.frac > 0
            newx = Int(fixed_mul(thing.momx, best.frac))
            newy = Int(fixed_mul(thing.momy, best.frac))
            if !try_move!(world, thing, thing.x + newx, thing.y + newy, game)
                stairstep!(world, thing, game)
                return
            end
        end
        best.frac = FRACUNIT - (best.frac + 2048)
        best.frac > FRACUNIT && (best.frac = FRACUNIT)
        best.frac <= 0 && return
        tmx = Int(fixed_mul(thing.momx, best.frac))
        tmy = Int(fixed_mul(thing.momy, best.frac))
        tmx, tmy = hit_slide_line(thing, best.line, tmx, tmy)
        thing.momx = tmx
        thing.momy = tmy
        if try_move!(world, thing, thing.x + tmx, thing.y + tmy, game)
            return
        end
    end
end

function use_lines!(world, player, game)
    mo = player.mo
    x1, y1 = mo.x, mo.y
    x2 = x1 + Int(shar(USERANGE, FRACBITS)) * Int(fine_cos(mo.angle))
    y2 = y1 + Int(shar(USERANGE, FRACBITS)) * Int(fine_sin(mo.angle))
    path_traverse(world, x1, y1, x2, y2, PT_ADDLINES, inn -> begin
        ln = inn.line
        if ln.special == 0
            opentop, openbottom, _ = line_opening(ln)
            if opentop - openbottom <= 0
                if game !== nothing && game.start_sound !== nothing
                    game.start_sound("noway")
                end
                return false
            end
            return true
        end
        side = point_on_line_side(mo.x, mo.y, ln) == 1 ? 1 : 0
        if game !== nothing && game.use_special !== nothing
            game.use_special(ln, mo, side)
        end
        false
    end)
    nothing
end

function shot_ends(source, angle, attackrange)
    x2 = source.x + Int(shar(attackrange, FRACBITS)) * Int(fine_cos(angle))
    y2 = source.y + Int(shar(attackrange, FRACBITS)) * Int(fine_sin(angle))
    shootz = source.z + Int(shar(source.height, 1)) + 8 * FRACUNIT
    x2, y2, shootz
end

function aim(world, source, angle, attackrange)
    x2, y2, shootz = shot_ends(source, angle, attackrange)
    window = fld(100 * FRACUNIT, 160)
    state = Dict{Symbol,Any}(:top => window, :bottom => -window, :slope => 0, :target => nothing)
    path_traverse(world, source.x, source.y, x2, y2, PT_ADDLINES + PT_ADDTHINGS, inn -> begin
        if inn.isaline
            li = inn.line
            has(li.flags, ML_TWOSIDED) || return false
            opentop, openbottom, _ = line_opening(li)
            openbottom >= opentop && return false
            dist = Int(fixed_mul(attackrange, inn.frac))
            front, back = li.frontsector, li.backsector
            if back === nothing || Int(front.floorheight) != Int(back.floorheight)
                slope = Int(fixed_div(openbottom - shootz, dist))
                slope > state[:bottom] && (state[:bottom] = slope)
            end
            if back === nothing || Int(front.ceilingheight) != Int(back.ceilingheight)
                slope = Int(fixed_div(opentop - shootz, dist))
                slope < state[:top] && (state[:top] = slope)
            end
            return state[:top] > state[:bottom]
        end
        th = inn.thing
        (th === source || !has(th.flags, MF_SHOOTABLE)) && return true
        dist = Int(fixed_mul(attackrange, inn.frac))
        thingtop = Int(fixed_div(th.z + th.height - shootz, dist))
        thingtop < state[:bottom] && return true
        thingbot = Int(fixed_div(th.z - shootz, dist))
        thingbot > state[:top] && return true
        thingtop > state[:top] && (thingtop = state[:top])
        thingbot < state[:bottom] && (thingbot = state[:bottom])
        state[:slope] = fld(thingtop + thingbot, 2)
        state[:target] = th
        false
    end)
    state[:target] === nothing && return 0, nothing
    state[:slope], state[:target]
end

function missile_aim(world, source)
    base = source.angle
    span = 16 * 64 * FRACUNIT
    shifted = as_u32(Int64(base) + (1 << 26))
    angles = (base, shifted, as_u32(Int64(shifted) - (2 << 26)))
    for ang in angles
        slope, target = aim(world, source, ang, span)
        target !== nothing && return ang, slope
    end
    base, 0
end

function bullet_slope(world, source)
    _, slope = missile_aim(world, source)
    slope
end

function spawn_fx(world, x, y, z, sprite, momz)
    sub = point_in_subsector(world, x, y)
    mo = new_mobj(
        x=x, y=y, z=z, momz=momz, radius=20 * FRACUNIT, height=16 * FRACUNIT,
        floorz=Int(sub.sector.floorheight), ceilingz=Int(sub.sector.ceilingheight),
        flags=MF_NOBLOCKMAP, sprite=sprite, fx=true, tics=8,
    )
    push!(world.mobjs, mo)
    mo
end

function spawn_puff(world, x, y, z, attackrange)
    z += (p_random() - p_random()) * 1024
    th = spawn_fx(world, x, y, z, "PUFF", FRACUNIT)
    p_random()
    th.tics -= Int(band(p_random(), 3))
    th.tics < 1 && (th.tics = 1)
    attackrange == MELEERANGE && (th.frame = 2)
    th
end

function spawn_blood(world, x, y, z, damage)
    z += (p_random() - p_random()) * 1024
    th = spawn_fx(world, x, y, z, "BLUD", FRACUNIT * 2)
    p_random()
    th.tics -= Int(band(p_random(), 3))
    th.tics < 1 && (th.tics = 1)
    if damage <= 12 && damage >= 9
        th.frame = 1
    elseif damage < 9
        th.frame = 2
    end
    th
end

function line_attack!(world, source, damage, game, attackrange, angle, slope)
    init_tables!()
    ang = angle === nothing ? source.angle : angle
    aimslope = slope === nothing ? aim(world, source, ang, attackrange)[1] : slope
    x2, y2, shootz = shot_ends(source, ang, attackrange)
    sky = -1
    if game !== nothing && game.res !== nothing
        sky = game.res.skyflatnum
    end
    hit = false
    path_traverse(world, source.x, source.y, x2, y2, PT_ADDLINES + PT_ADDTHINGS, inn -> begin
        if inn.isaline
            li = inn.line
            if li.special != 0 && game !== nothing && game.shoot_special !== nothing
                game.shoot_special(li, source)
            end
            hit_line = false
            if !has(li.flags, ML_TWOSIDED)
                hit_line = true
            else
                opentop, openbottom, _ = line_opening(li)
                dist = Int(fixed_mul(attackrange, inn.frac))
                front, back = li.frontsector, li.backsector
                if back === nothing
                    if Int(fixed_div(openbottom - shootz, dist)) > aimslope
                        hit_line = true
                    elseif Int(fixed_div(opentop - shootz, dist)) < aimslope
                        hit_line = true
                    end
                else
                    if Int(front.floorheight) != Int(back.floorheight) && Int(fixed_div(openbottom - shootz, dist)) > aimslope
                        hit_line = true
                    end
                    if !hit_line && Int(front.ceilingheight) != Int(back.ceilingheight) && Int(fixed_div(opentop - shootz, dist)) < aimslope
                        hit_line = true
                    end
                end
            end
            hit_line || return true
            frac = inn.frac - Int(fixed_div(4 * FRACUNIT, attackrange))
            x = trace.x + Int(fixed_mul(trace.dx, frac))
            y = trace.y + Int(fixed_mul(trace.dy, frac))
            z = shootz + Int(fixed_mul(aimslope, Int(fixed_mul(frac, attackrange))))
            front = li.frontsector
            if front !== nothing && front.ceilingpic == sky
                if z > Int(front.ceilingheight)
                    return false
                end
                if li.backsector !== nothing && li.backsector.ceilingpic == sky
                    return false
                end
            end
            spawn_puff(world, x, y, z, attackrange)
            return false
        end
        th = inn.thing
        (th === source || !has(th.flags, MF_SHOOTABLE)) && return true
        dist = Int(fixed_mul(attackrange, inn.frac))
        Int(fixed_div(th.z + th.height - shootz, dist)) < aimslope && return true
        Int(fixed_div(th.z - shootz, dist)) > aimslope && return true
        frac = inn.frac - Int(fixed_div(10 * FRACUNIT, attackrange))
        x = trace.x + Int(fixed_mul(trace.dx, frac))
        y = trace.y + Int(fixed_mul(trace.dy, frac))
        z = shootz + Int(fixed_mul(aimslope, Int(fixed_mul(frac, attackrange))))
        if has(th.flags, MF_NOBLOOD)
            spawn_puff(world, x, y, z, attackrange)
        else
            spawn_blood(world, x, y, z, damage)
        end
        if damage != 0
            call_damage(game, th, source, damage, source)
        end
        hit = true
        false
    end)
    hit
end

function thing_height_clip!(world, thing)
    on_floor = thing.z == thing.floorz
    chk = check_position(world, thing, thing.x, thing.y, nothing)
    thing.floorz = chk.floorz
    thing.ceilingz = chk.ceilingz
    if on_floor
        thing.z = thing.floorz
    elseif thing.z + thing.height > thing.ceilingz
        thing.z = thing.ceilingz - thing.height
    end
    if thing.player !== nothing
        thing.player.viewz = thing.z + thing.player.viewheight
    end
    thing.ceilingz - thing.floorz >= thing.height
end

function change_sector!(world, sector, crush)
    nofit = false
    for thing in world.mobjs
        point_in_subsector(world, thing.x, thing.y).sector !== sector && continue
        if !thing_height_clip!(world, thing)
            if thing.health <= 0
                thing.flags = Int(band(thing.flags, bnot(MF_SOLID)))
                thing.height = 0
            elseif has(thing.flags, MF_SHOOTABLE)
                nofit = true
                if crush
                    thing.health -= 10
                    if thing.player !== nothing
                        thing.player.health = thing.health
                    end
                    if thing.health <= 0
                        thing.health = 0
                        if thing.player !== nothing
                            thing.player.health = 0
                        end
                        thing.flags = Int(band(thing.flags, bnot(MF_SOLID)))
                        thing.height = 0
                    end
                end
            end
        end
    end
    nofit
end

function intercept_frac(x1, y1, x2, y2, line)
    ax, ay = x1 / 65536, y1 / 65536
    bx, by = x2 / 65536, y2 / 65536
    cx, cy = line.v1.x / 65536, line.v1.y / 65536
    dx, dy = line.v2.x / 65536, line.v2.y / 65536
    den = (bx - ax) * (dy - cy) - (by - ay) * (dx - cx)
    abs(den) < 1e-8 && return nothing
    t = ((cx - ax) * (dy - cy) - (cy - ay) * (dx - cx)) / den
    u = ((cx - ax) * (by - ay) - (cy - ay) * (bx - ax)) / den
    (t < 0 || t > 1 || u < 0 || u > 1) && return nothing
    floor(Int, t * 65536)
end

function check_sight(world, t1, t2)
    s1 = point_in_subsector(world, t1.x, t1.y).sector
    s2 = point_in_subsector(world, t2.x, t2.y).sector
    nsec = length(world.sectors)
    rej = world.rejectmatrix
    if nsec > 0 && !isempty(rej)
        pnum = s1.i_sector * nsec + s2.i_sector
        bytenum = fld(pnum, 8)
        bitnum = 1 << (pnum % 8)
        if bytenum < length(rej) && band(rej[bytenum + 1], bitnum) != 0
            return false
        end
    end
    s1 === s2 && return true
    margin = fld(65536, 64)
    for ln in world.lines
        open = false
        if ln.backsector !== nothing
            opentop, openbottom, _ = line_opening(ln)
            open = opentop - openbottom > 0
        end
        if !open
            frac = intercept_frac(t1.x, t1.y, t2.x, t2.y, ln)
            if frac !== nothing && margin < frac && frac < 65536 - margin
                return false
            end
        end
    end
    true
end

function aim_slope(world, source, angle, attackrange)
    slope, target = aim(world, source, angle, attackrange)
    target === nothing ? 0 : slope
end

function aim_line_attack(world, source, angle, attackrange)
    _, target = aim(world, source, angle, attackrange)
    target
end

end

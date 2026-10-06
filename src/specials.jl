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
# Portas, plataformas, pisos, tetos e interruptores, a partir de specials.py.
# A contagem da intermissao fica para a fase 13.

module Specials

using ..Compat
using ..RData
using ..Rng
using ..Collision

export new_specials, tick!, use_special, cross_special, shoot_special, move_plane
export do_floor_tag, do_door_tag, raise_to_texture_tag, lowest_floor, VLD_BLAZEOPEN

const FRACUNIT = 65536
const TICRATE = 35
const VDOORSPEED = 2 * FRACUNIT
const VDOORWAIT = 150
const PLATSPEED = FRACUNIT
const PLATWAIT = 3
const FLOORSPEED = FRACUNIT
const CEILSPEED = FRACUNIT
const GLOWSPEED = 8
const STROBEBRIGHT = 5
const FASTDARK = 15
const SLOWDARK = 35
const BUTTONTIME = 35
const CEIL_LOWERTOFLOOR = 0
const CEIL_RAISETOHIGHEST = 1
const CEIL_LOWERANDCRUSH = 2
const CEIL_CRUSHANDRAISE = 3
const CEIL_FASTCRUSH = 4
const CEIL_SILENTCRUSH = 5
const RESULT_CRUSHED = 1
const RESULT_PASTDEST = 2
const PLAT_DOWN = 0
const PLAT_UP = 1
const PLAT_WAITING = 2
const PLAT_DWUS = 0
const PLAT_PERPETUAL = 1
const PLAT_BLAZEDWUS = 2
const VLD_NORMAL = 0
const VLD_CLOSE30 = 1
const VLD_CLOSE = 2
const VLD_OPEN = 3
const VLD_RAISEIN5 = 4
const VLD_BLAZERAISE = 5
const VLD_BLAZEOPEN = 6
const VLD_BLAZECLOSE = 7
const ML_TWOSIDED = 4
const MF_MISSILE = 65536
const IT_BLUECARD = 0
const IT_YELLOWCARD = 1
const IT_REDCARD = 2
const IT_BLUESKULL = 3
const IT_YELLOWSKULL = 4
const IT_REDSKULL = 5

const SWITCH_PAIRS = (
    ("SW1BRCOM", "SW2BRCOM"), ("SW1BRN1", "SW2BRN1"), ("SW1BRN2", "SW2BRN2"),
    ("SW1BRNGN", "SW2BRNGN"), ("SW1BROWN", "SW2BROWN"), ("SW1COMM", "SW2COMM"),
    ("SW1COMP", "SW2COMP"), ("SW1DIRT", "SW2DIRT"), ("SW1EXIT", "SW2EXIT"),
    ("SW1GRAY", "SW2GRAY"), ("SW1GRAY1", "SW2GRAY1"), ("SW1METAL", "SW2METAL"),
    ("SW1PIPE", "SW2PIPE"), ("SW1SLAD", "SW2SLAD"), ("SW1STARG", "SW2STARG"),
    ("SW1STON1", "SW2STON1"), ("SW1STON2", "SW2STON2"), ("SW1STONE", "SW2STONE"),
    ("SW1STRTN", "SW2STRTN"), ("SW1BLUE", "SW2BLUE"), ("SW1CMT", "SW2CMT"),
    ("SW1GARG", "SW2GARG"), ("SW1GSTON", "SW2GSTON"), ("SW1HOT", "SW2HOT"),
    ("SW1LION", "SW2LION"), ("SW1SATYR", "SW2SATYR"), ("SW1SKIN", "SW2SKIN"),
    ("SW1VINE", "SW2VINE"), ("SW1WOOD", "SW2WOOD"), ("SW1PANEL", "SW2PANEL"),
    ("SW1ROCK", "SW2ROCK"), ("SW1MET2", "SW2MET2"), ("SW1WDMET", "SW2WDMET"),
    ("SW1BRIK", "SW2BRIK"), ("SW1MOD1", "SW2MOD1"), ("SW1ZIM", "SW2ZIM"),
    ("SW1STON6", "SW2STON6"), ("SW1TEK", "SW2TEK"), ("SW1MARB", "SW2MARB"),
    ("SW1SKULL", "SW2SKULL"),
)

const TEX_FIELDS = (:toptexture, :midtexture, :bottomtexture)

has(flags, bit) = band(flags, bit) != 0
hgt(x) = Int(x)
card(player, i) = player.cards[i + 1]

mutable struct SpecState
    world::Any
    res::Any
    sound::Any
    thinkers::Vector{Any}
    lights::Vector{Any}
    scroll_lines::Vector{Any}
    buttons::Vector{Any}
    exit_requested::Bool
    secret_exit::Bool
    switch_map::Dict{Int,Int}
    stamp::Int
end

mutable struct Light
    sector::Any
    kind::String
    maxlight::Int
    minlight::Int
    maxtime::Int
    mintime::Int
    count::Int
    darktime::Int
    brighttime::Int
    direction::Int
end

mutable struct Door
    sector::Any
    type::Int
    direction::Int
    topheight::Int
    speed::Int
    topwait::Int
    topcountdown::Int
    dead::Bool
end

mutable struct Plat
    sector::Any
    type::Int
    status::Int
    speed::Int
    low::Int
    high::Int
    wait::Int
    count::Int
    dead::Bool
end

mutable struct FloorMove
    sector::Any
    direction::Int
    dest::Int
    speed::Int
    crush::Bool
    floorpic::Any
    dead::Bool
end

mutable struct Ceiling
    sector::Any
    direction::Int
    dest::Int
    speed::Int
    crush::Bool
    ctype::Int
    topheight::Int
    bottomheight::Int
    dead::Bool
end

mutable struct Button
    line::Any
    attr::Symbol
    texture::Int
    timer::Int
end

kindof(th::Door) = "door"
kindof(th::Plat) = "plat"
kindof(th::FloorMove) = "floor"
kindof(th::Ceiling) = "ceiling"

mark!(self) = (self.stamp += 1)

function move_plane(world, sector, speed, dest, floor_or_ceiling, direction, crush)
    last = floor_or_ceiling == 0 ? hgt(sector.floorheight) : hgt(sector.ceilingheight)
    past = false
    next_h = last
    if direction == -1
        if last - speed < dest
            next_h = dest
            past = true
        else
            next_h = last - speed
        end
    elseif last + speed > dest
        next_h = dest
        past = true
    else
        next_h = last + speed
    end
    if floor_or_ceiling == 0
        sector.floorheight = as_i32(next_h)
    else
        sector.ceilingheight = as_i32(next_h)
    end
    nofit = change_sector!(world, sector, crush)
    if nofit
        if !crush || past
            if floor_or_ceiling == 0
                sector.floorheight = as_i32(last)
            else
                sector.ceilingheight = as_i32(last)
            end
            change_sector!(world, sector, crush)
        end
        return past ? RESULT_PASTDEST : RESULT_CRUSHED
    end
    past ? RESULT_PASTDEST : 0
end

function surrounding_sectors(sector)
    seen = Any[]
    for ln in sector.lines
        other = ln.frontsector !== sector ? ln.frontsector : ln.backsector
        (other === nothing || other === sector) && continue
        other in seen || push!(seen, other)
    end
    seen
end

function lowest_ceiling(sector)
    h = 2147483647
    for other in surrounding_sectors(sector)
        hgt(other.ceilingheight) < h && (h = hgt(other.ceilingheight))
    end
    h == 2147483647 ? hgt(sector.ceilingheight) : h
end

function lowest_floor(sector)
    h = hgt(sector.floorheight)
    for other in surrounding_sectors(sector)
        hgt(other.floorheight) < h && (h = hgt(other.floorheight))
    end
    h
end

function highest_floor(sector)
    h = -500 * FRACUNIT
    for other in surrounding_sectors(sector)
        hgt(other.floorheight) > h && (h = hgt(other.floorheight))
    end
    h
end

function next_highest_floor(sector, current)
    min_h = 2147483647
    found = false
    for other in surrounding_sectors(sector)
        fh = hgt(other.floorheight)
        if fh > current && fh < min_h
            min_h = fh
            found = true
        end
    end
    found ? min_h : current
end

function highest_ceiling(sector)
    h = hgt(sector.ceilingheight)
    for other in surrounding_sectors(sector)
        hgt(other.ceilingheight) > h && (h = hgt(other.ceilingheight))
    end
    h
end

raise_floor_dest(sector) = min(lowest_ceiling(sector), hgt(sector.ceilingheight))
raise_floor_crush_dest(sector) = raise_floor_dest(sector) - 8 * FRACUNIT

function min_surrounding_light(sector, maxlight)
    low = maxlight
    for other in surrounding_sectors(sector)
        other.lightlevel < low && (low = other.lightlevel)
    end
    low
end

function max_surrounding_light(sector)
    high = sector.lightlevel
    for other in surrounding_sectors(sector)
        other.lightlevel > high && (high = other.lightlevel)
    end
    high
end

function sectors_from_tag(world, tag)
    out = Any[]
    tag == 0 && return out
    for sector in world.sectors
        sector.tag == tag && push!(out, sector)
    end
    out
end

function spawn_light_flash!(self, sector)
    sector.special = 0
    flash = Light(sector, "flash", sector.lightlevel, min_surrounding_light(sector, sector.lightlevel), 64, 7, 0, 0, 0, 0)
    flash.count = Int(band(p_random(), flash.maxtime)) + 1
    push!(self.lights, flash)
    mark!(self)
end

function spawn_strobe!(self, sector, darktime, synced)
    sector.special = 0
    minl = min_surrounding_light(sector, sector.lightlevel)
    minl == sector.lightlevel && (minl = 0)
    count = synced ? 1 : Int(band(p_random(), 7)) + 1
    push!(self.lights, Light(sector, "strobe", sector.lightlevel, minl, 0, 0, count, darktime, STROBEBRIGHT, 0))
    mark!(self)
end

function spawn_glow!(self, sector)
    sector.special = 0
    push!(self.lights, Light(sector, "glow", sector.lightlevel, min_surrounding_light(sector, sector.lightlevel), 0, 0, 0, 0, 0, -1))
    mark!(self)
end

function spawn_fire!(self, sector)
    sector.special = 0
    push!(self.lights, Light(sector, "fire", sector.lightlevel, min_surrounding_light(sector, sector.lightlevel) + 16, 0, 0, 4, 0, 0, 0))
    mark!(self)
end

function hear(self, name)
    f = self.sound
    f isa Function && f(name)
    nothing
end

function spawn_door!(self, sector, dtype, reverse)
    if sector.specialdata !== nothing
        door = sector.specialdata
        if door isa Door && (dtype == VLD_NORMAL || dtype == VLD_BLAZERAISE)
            door.direction = door.direction == -1 ? 1 : -1
            return true
        end
        return false
    end
    direction = 1
    (reverse || dtype == VLD_CLOSE || dtype == VLD_BLAZECLOSE || dtype == VLD_CLOSE30) && (direction = -1)
    speed = dtype >= VLD_BLAZERAISE ? VDOORSPEED * 4 : VDOORSPEED
    door = Door(sector, dtype, direction, lowest_ceiling(sector) - 4 * FRACUNIT, speed, VDOORWAIT, 0, false)
    dtype == VLD_CLOSE30 && (door.topheight = hgt(sector.ceilingheight))
    sector.specialdata = door
    push!(self.thinkers, door)
    if door.direction == 1
        hear(self, dtype < VLD_BLAZERAISE ? "doropn" : "bdopn")
    else
        hear(self, dtype < VLD_BLAZERAISE ? "dorcls" : "bdcls")
    end
    true
end

function spawn_door_close_in_30!(self, sector)
    sector.specialdata !== nothing && return
    sector.special = 0
    door = Door(sector, VLD_CLOSE, 0, hgt(sector.ceilingheight), VDOORSPEED, VDOORWAIT, 30 * TICRATE, false)
    sector.specialdata = door
    push!(self.thinkers, door)
end

function spawn_door_raise_in_5!(self, sector)
    sector.specialdata !== nothing && return
    sector.special = 0
    door = Door(sector, VLD_RAISEIN5, 0, lowest_ceiling(sector) - 4 * FRACUNIT, VDOORSPEED, VDOORWAIT, 5 * 60 * TICRATE, false)
    sector.specialdata = door
    push!(self.thinkers, door)
end

function spawn_specials!(self)
    for sector in self.world.sectors
        spec = sector.special
        if spec == 1
            spawn_light_flash!(self, sector)
        elseif spec == 2
            spawn_strobe!(self, sector, FASTDARK, false)
        elseif spec == 4
            spawn_strobe!(self, sector, FASTDARK, false)
            sector.special = 4
        elseif spec == 3
            spawn_strobe!(self, sector, SLOWDARK, false)
        elseif spec == 8
            spawn_glow!(self, sector)
        elseif spec == 10
            spawn_door_close_in_30!(self, sector)
        elseif spec == 12
            spawn_strobe!(self, sector, SLOWDARK, true)
        elseif spec == 13
            spawn_strobe!(self, sector, FASTDARK, true)
        elseif spec == 14
            spawn_door_raise_in_5!(self, sector)
        elseif spec == 17
            spawn_fire!(self, sector)
        end
    end
    for ln in self.world.lines
        ln.special == 48 && push!(self.scroll_lines, ln)
    end
    nothing
end

function new_specials(world, res, sound)
    self = SpecState(world, res, sound, Any[], Any[], Any[], Any[], false, false, Dict{Int,Int}(), 0)
    for (a, b) in SWITCH_PAIRS
        ia = texture_num_for_name(res, a)
        ib = texture_num_for_name(res, b)
        if ia != 0 || ib != 0
            self.switch_map[ia] = ib
            self.switch_map[ib] = ia
        end
    end
    spawn_specials!(self)
    self
end

function tick_lights!(self)
    for light in self.lights
        if light.kind == "glow"
            if light.direction == -1
                light.sector.lightlevel -= GLOWSPEED
                if light.sector.lightlevel <= light.minlight
                    light.sector.lightlevel += GLOWSPEED
                    light.direction = 1
                end
            else
                light.sector.lightlevel += GLOWSPEED
                if light.sector.lightlevel >= light.maxlight
                    light.sector.lightlevel -= GLOWSPEED
                    light.direction = -1
                end
            end
            mark!(self)
        else
            light.count -= 1
            light.count == 0 || continue
            if light.kind == "flash"
                if light.sector.lightlevel == light.maxlight
                    light.sector.lightlevel = light.minlight
                    light.count = Int(band(p_random(), light.mintime)) + 1
                else
                    light.sector.lightlevel = light.maxlight
                    light.count = Int(band(p_random(), light.maxtime)) + 1
                end
            elseif light.kind == "strobe"
                if light.sector.lightlevel == light.minlight
                    light.sector.lightlevel = light.maxlight
                    light.count = light.brighttime
                else
                    light.sector.lightlevel = light.minlight
                    light.count = light.darktime
                end
            elseif light.kind == "fire"
                amount = Int(band(p_random(), 3)) * 16
                if light.sector.lightlevel - amount < light.minlight
                    light.sector.lightlevel = light.minlight
                else
                    light.sector.lightlevel = light.maxlight - amount
                end
                light.count = 4
            end
            mark!(self)
        end
    end
end

function tick_door!(self, door)
    if door.direction == 0
        door.topcountdown -= 1
        door.topcountdown > 0 && return
        dtype = door.type
        if dtype == VLD_NORMAL || dtype == VLD_BLAZERAISE || dtype == VLD_CLOSE
            door.direction = -1
            hear(self, dtype == VLD_BLAZERAISE ? "bdcls" : "dorcls")
        elseif dtype == VLD_CLOSE30 || dtype == VLD_RAISEIN5
            door.direction = 1
            hear(self, "doropn")
        end
        return
    end
    dest = door.direction == 1 ? door.topheight : hgt(door.sector.floorheight)
    res = move_plane(self.world, door.sector, door.speed, dest, 1, door.direction, false)
    mark!(self)
    res != RESULT_PASTDEST && return
    if door.direction == 1
        if door.type == VLD_NORMAL || door.type == VLD_BLAZERAISE
            door.direction = 0
            door.topcountdown = door.topwait
        else
            door.sector.specialdata = nothing
            door.dead = true
        end
    elseif door.type == VLD_CLOSE30
        door.direction = 0
        door.topcountdown = TICRATE * 30
    else
        door.sector.specialdata = nothing
        door.dead = true
    end
end

function tick_plat!(self, plat)
    if plat.status == PLAT_WAITING
        plat.count -= 1
        plat.count > 0 && return
        plat.status = hgt(plat.sector.floorheight) <= plat.low ? PLAT_UP : PLAT_DOWN
        hear(self, "pstart")
        return
    end
    dest = plat.low
    direction = -1
    if plat.status == PLAT_UP
        dest = plat.high
        direction = 1
    end
    res = move_plane(self.world, plat.sector, plat.speed, dest, 0, direction, false)
    mark!(self)
    res == RESULT_PASTDEST || return
    if plat.status == PLAT_DOWN || plat.type == PLAT_PERPETUAL
        plat.status = PLAT_WAITING
        plat.count = plat.wait
    else
        plat.sector.specialdata = nothing
        plat.dead = true
    end
    hear(self, "pstop")
end

function tick_floor!(self, floor)
    res = move_plane(self.world, floor.sector, floor.speed, floor.dest, 0, floor.direction, floor.crush)
    mark!(self)
    res == RESULT_PASTDEST || return
    floor.floorpic !== nothing && (floor.sector.floorpic = floor.floorpic)
    floor.sector.specialdata = nothing
    floor.dead = true
end

function tick_ceiling!(self, ceil)
    dest = ceil.dest
    if ceil.ctype != 0
        dest = ceil.direction == 1 ? ceil.topheight : ceil.bottomheight
    end
    res = move_plane(self.world, ceil.sector, ceil.speed, dest, 1, ceil.direction, ceil.crush)
    mark!(self)
    bounce = ceil.ctype == CEIL_CRUSHANDRAISE || ceil.ctype == CEIL_FASTCRUSH || ceil.ctype == CEIL_SILENTCRUSH
    if res == RESULT_PASTDEST
        if bounce
            if ceil.direction == -1
                ceil.direction = 1
                ceil.speed = ceil.ctype == CEIL_FASTCRUSH ? CEILSPEED * 2 : CEILSPEED
                ceil.ctype == CEIL_SILENTCRUSH && hear(self, "pstop")
            else
                ceil.direction = -1
                ceil.ctype == CEIL_SILENTCRUSH && hear(self, "pstop")
            end
        else
            ceil.sector.specialdata = nothing
            ceil.dead = true
        end
    elseif res == RESULT_CRUSHED && bounce
        slow = fld(CEILSPEED, 8)
        ceil.speed = slow < 1 ? 1 : slow
    end
end

function tick!(self)
    before = self.stamp
    tick_lights!(self)
    for ln in self.scroll_lines
        side = ln.sides[1]
        if side !== nothing
            side.textureoffset = as_i32(Int(side.textureoffset) + FRACUNIT)
            mark!(self)
        end
    end
    alive = Any[]
    for th in self.thinkers
        th.dead && continue
        if th isa Door
            tick_door!(self, th)
        elseif th isa Plat
            tick_plat!(self, th)
        elseif th isa FloorMove
            tick_floor!(self, th)
        elseif th isa Ceiling
            tick_ceiling!(self, th)
        end
        th.dead || push!(alive, th)
    end
    self.thinkers = alive
    keep = Button[]
    for btn in self.buttons
        btn.timer -= 1
        if btn.timer <= 0
            side = btn.line.sides[1]
            if side !== nothing
                setproperty!(side, btn.attr, btn.texture)
                mark!(self)
            end
        else
            push!(keep, btn)
        end
    end
    self.buttons = keep
    self.stamp != before
end

function do_door(self, line, dtype, reverse=false)
    ok = false
    for sec in sectors_from_tag(self.world, line.tag)
        spawn_door!(self, sec, dtype, reverse) && (ok = true)
    end
    ok
end

function vertical_door(self, line, thing)
    player = thing === nothing ? nothing : thing.player
    spec = line.special
    if player !== nothing && (spec == 26 || spec == 32 || spec == 99 || spec == 133)
        if !card(player, IT_BLUECARD) && !card(player, IT_BLUESKULL)
            player.message = "You need a blue key to open this door"
            hear(self, "oof")
            return
        end
    end
    if player !== nothing && (spec == 27 || spec == 34 || spec == 136 || spec == 137)
        if !card(player, IT_YELLOWCARD) && !card(player, IT_YELLOWSKULL)
            player.message = "You need a yellow key to open this door"
            hear(self, "oof")
            return
        end
    end
    if player !== nothing && (spec == 28 || spec == 33 || spec == 134 || spec == 135)
        if !card(player, IT_REDCARD) && !card(player, IT_REDSKULL)
            player.message = "You need a red key to open this door"
            hear(self, "oof")
            return
        end
    end
    side = line.sides[2]
    (side === nothing || side.sector === nothing) && return
    dtype = VLD_NORMAL
    if spec == 31 || spec == 32 || spec == 33 || spec == 34
        dtype = VLD_OPEN
        line.special = 0
    elseif spec == 117
        dtype = VLD_BLAZERAISE
    elseif spec in (118, 99, 133, 134, 135, 136, 137)
        dtype = VLD_BLAZEOPEN
        line.special = 0
    end
    spawn_door!(self, side.sector, dtype, false)
    nothing
end

function do_plat_dwus(self, line, blaze)
    ok = false
    speed = blaze ? PLATSPEED * 8 : PLATSPEED
    for sec in sectors_from_tag(self.world, line.tag)
        sec.specialdata !== nothing && continue
        plat = Plat(sec, blaze ? PLAT_BLAZEDWUS : PLAT_DWUS, PLAT_DOWN, speed, lowest_floor(sec), hgt(sec.floorheight), PLATWAIT * TICRATE, 0, false)
        plat.low == plat.high && (plat.low = plat.high - 8 * FRACUNIT)
        sec.specialdata = plat
        push!(self.thinkers, plat)
        hear(self, "pstart")
        ok = true
    end
    ok
end

function do_floor(self, line, dest_fn, direction, speed=FLOORSPEED, crush=false)
    ok = false
    for sec in sectors_from_tag(self.world, line.tag)
        sec.specialdata !== nothing && continue
        floor = FloorMove(sec, direction, dest_fn(sec), speed, crush, nothing, false)
        sec.specialdata = floor
        push!(self.thinkers, floor)
        ok = true
    end
    ok
end

function do_stairs(self, line, step, speed)
    ok = false
    for sec in sectors_from_tag(self.world, line.tag)
        sec.specialdata !== nothing && continue
        height = hgt(sec.floorheight) + step
        floor = FloorMove(sec, 1, height, speed, false, nothing, false)
        sec.specialdata = floor
        push!(self.thinkers, floor)
        ok = true
        texture = sec.floorpic
        cur = sec
        while true
            nxt = nothing
            for ln in cur.lines
                has(ln.flags, ML_TWOSIDED) || continue
                other = ln.frontsector !== cur ? ln.frontsector : ln.backsector
                if other !== nothing && other !== cur && other.floorpic == texture && other.specialdata === nothing
                    nxt = other
                    break
                end
            end
            nxt === nothing && break
            height += step
            moved = FloorMove(nxt, 1, height, speed, false, nothing, false)
            nxt.specialdata = moved
            push!(self.thinkers, moved)
            cur = nxt
        end
    end
    ok
end

function start_floor(self, sec, dest, direction, speed, crush, floorpic)
    sec.specialdata !== nothing && return false
    floor = FloorMove(sec, direction, dest, speed, crush, floorpic, false)
    sec.specialdata = floor
    push!(self.thinkers, floor)
    true
end

function do_crusher(self, line, ctype)
    ok = false
    for sec in sectors_from_tag(self.world, line.tag)
        sec.specialdata !== nothing && continue
        top = hgt(sec.ceilingheight)
        bottom = hgt(sec.floorheight)
        crush = ctype != CEIL_RAISETOHIGHEST
        speed = ctype == CEIL_FASTCRUSH ? CEILSPEED * 2 : CEILSPEED
        direction = -1
        dest = bottom
        if ctype == CEIL_RAISETOHIGHEST
            dest = highest_ceiling(sec)
            direction = 1
            crush = false
        elseif ctype != CEIL_LOWERTOFLOOR
            bottom += 8 * FRACUNIT
            dest = bottom
        end
        ceil = Ceiling(sec, direction, dest, speed, crush, ctype, top, bottom, false)
        sec.specialdata = ceil
        push!(self.thinkers, ceil)
        ok = true
    end
    ok
end

function do_donut(self, line)
    ok = false
    half = fld(FLOORSPEED, 2)
    for s1 in sectors_from_tag(self.world, line.tag)
        (s1.specialdata !== nothing || isempty(s1.lines)) && continue
        first = s1.lines[1]
        s2 = first.frontsector !== s1 ? first.frontsector : first.backsector
        s2 === nothing && continue
        s3 = nothing
        for ln in s2.lines
            other = ln.backsector
            if other !== nothing && other !== s1
                s3 = other
                break
            end
        end
        s3 === nothing && continue
        start_floor(self, s2, hgt(s3.floorheight), 1, half, false, s3.floorpic) && (ok = true)
        start_floor(self, s1, hgt(s3.floorheight), -1, half, false, nothing) && (ok = true)
    end
    ok
end

function do_plat_perpetual(self, line)
    ok = false
    for sec in sectors_from_tag(self.world, line.tag)
        sec.specialdata !== nothing && continue
        low = lowest_floor(sec)
        high = highest_floor(sec)
        low > hgt(sec.floorheight) && (low = hgt(sec.floorheight))
        high < hgt(sec.floorheight) && (high = hgt(sec.floorheight))
        plat = Plat(sec, PLAT_PERPETUAL, Int(band(p_random(), 1)), PLATSPEED, low, high, PLATWAIT * TICRATE, 0, false)
        sec.specialdata = plat
        push!(self.thinkers, plat)
        hear(self, "pstart")
        ok = true
    end
    ok
end

function do_plat_raise(self, line, amount, change=true)
    ok = false
    pic = nothing
    if change && line.sides[1] !== nothing && line.sides[1].sector !== nothing
        pic = line.sides[1].sector.floorpic
    end
    for sec in sectors_from_tag(self.world, line.tag)
        sec.specialdata !== nothing && continue
        high = amount != 0 ? hgt(sec.floorheight) + amount : next_highest_floor(sec, hgt(sec.floorheight))
        if pic !== nothing
            sec.floorpic = pic
            mark!(self)
        end
        plat = Plat(sec, PLAT_DWUS, PLAT_UP, fld(PLATSPEED, 2), hgt(sec.floorheight), high, 0, 0, false)
        sec.specialdata = plat
        push!(self.thinkers, plat)
        hear(self, "pstart")
        ok = true
    end
    ok
end

function stop_plat(self, line)
    ok = false
    for th in self.thinkers
        if th isa Plat && !th.dead && th.sector.tag == line.tag
            th.status = PLAT_WAITING
            th.count = 2147483647
            ok = true
        end
    end
    ok
end

function raise_to_texture(self, line)
    ok = false
    for sec in sectors_from_tag(self.world, line.tag)
        sec.specialdata !== nothing && continue
        minsize = 2147483647
        for ln in sec.lines
            has(ln.flags, ML_TWOSIDED) || continue
            for side in ln.sides
                side === nothing && continue
                side.bottomtexture <= 0 && continue
                h = texture_height(self.res, side.bottomtexture)
                if h > 0 && h < minsize
                    minsize = h
                end
            end
        end
        minsize == 2147483647 && (minsize = 64 * FRACUNIT)
        start_floor(self, sec, hgt(sec.floorheight) + minsize, 1, FLOORSPEED, false, nothing) && (ok = true)
    end
    ok
end

function lower_and_change(self, line)
    ok = false
    for sec in sectors_from_tag(self.world, line.tag)
        sec.specialdata !== nothing && continue
        dest = lowest_floor(sec)
        pic = sec.floorpic
        for other in surrounding_sectors(sec)
            if hgt(other.floorheight) == dest
                pic = other.floorpic
                break
            end
        end
        start_floor(self, sec, dest, -1, FLOORSPEED, false, pic) && (ok = true)
    end
    ok
end

function light_turn_on(self, line, bright)
    ok = false
    for sec in sectors_from_tag(self.world, line.tag)
        sec.lightlevel = bright != 0 ? bright : max_surrounding_light(sec)
        mark!(self)
        ok = true
    end
    ok
end

function turn_tag_lights_off(self, line)
    ok = false
    for sec in sectors_from_tag(self.world, line.tag)
        sec.lightlevel = min_surrounding_light(sec, sec.lightlevel)
        mark!(self)
        ok = true
    end
    ok
end

function start_light_strobing(self, line)
    ok = false
    for sec in sectors_from_tag(self.world, line.tag)
        if sec.specialdata === nothing
            spawn_strobe!(self, sec, SLOWDARK, false)
            ok = true
        end
    end
    ok
end

function change_switch(self, line, use_again)
    side = line.sides[1]
    side === nothing && return
    use_again || (line.special = 0)
    sound = line.special == 11 ? "swtchx" : "swtchn"
    for attr in TEX_FIELDS
        tex = Int(getproperty(side, attr))
        new = get(self.switch_map, tex, nothing)
        new === nothing && continue
        if use_again
            push!(self.buttons, Button(line, attr, tex, BUTTONTIME))
        end
        setproperty!(side, attr, new)
        mark!(self)
        hear(self, sound)
        return
    end
    hear(self, sound)
    nothing
end

function use_special(self, line, thing, side)
    side != 0 && return false
    spec = line.special
    if spec in (1, 26, 27, 28, 31, 32, 33, 34, 99, 117, 118, 133, 134, 135, 136, 137)
        vertical_door(self, line, thing)
        return true
    end
    if spec == 11
        change_switch(self, line, false)
        self.exit_requested = true
        return true
    end
    if spec == 51
        change_switch(self, line, false)
        self.exit_requested = true
        self.secret_exit = true
        return true
    end
    door(dtype) = do_door(self, line, dtype, false)
    tagged = Dict{Int,Function}(
        29 => () -> door(VLD_NORMAL),
        50 => () -> door(VLD_CLOSE),
        103 => () -> door(VLD_OPEN),
        111 => () -> door(VLD_BLAZERAISE),
        112 => () -> door(VLD_BLAZEOPEN),
        113 => () -> door(VLD_BLAZECLOSE),
        21 => () -> do_plat_dwus(self, line, false),
        122 => () -> do_plat_dwus(self, line, true),
        18 => () -> do_floor(self, line, s -> next_highest_floor(s, hgt(s.floorheight)), 1),
        23 => () -> do_floor(self, line, lowest_floor, -1),
        71 => () -> do_floor(self, line, highest_floor, -1),
        101 => () -> do_floor(self, line, raise_floor_dest, 1),
        102 => () -> do_floor(self, line, s -> hgt(s.floorheight) - 8 * FRACUNIT, -1),
        7 => () -> do_stairs(self, line, 8 * FRACUNIT, fld(FLOORSPEED, 4)),
        127 => () -> do_stairs(self, line, 16 * FRACUNIT, FLOORSPEED * 4),
        41 => () -> do_crusher(self, line, CEIL_LOWERTOFLOOR),
        49 => () -> do_crusher(self, line, CEIL_CRUSHANDRAISE),
        9 => () -> do_donut(self, line),
        14 => () -> do_plat_raise(self, line, 32 * FRACUNIT, true),
        15 => () -> do_plat_raise(self, line, 24 * FRACUNIT, true),
        20 => () -> do_plat_raise(self, line, 0, true),
        55 => () -> do_floor(self, line, raise_floor_crush_dest, 1, FLOORSPEED, true),
        131 => () -> do_floor(self, line, s -> next_highest_floor(s, hgt(s.floorheight)), 1, FLOORSPEED * 4),
        140 => () -> do_floor(self, line, s -> hgt(s.floorheight) + 512 * FRACUNIT, 1),
    )
    retrigger = Dict{Int,Function}(
        42 => () -> door(VLD_CLOSE),
        61 => () -> door(VLD_OPEN),
        63 => () -> door(VLD_NORMAL),
        62 => () -> do_plat_dwus(self, line, false),
        114 => () -> door(VLD_BLAZERAISE),
        115 => () -> door(VLD_BLAZEOPEN),
        116 => () -> door(VLD_BLAZECLOSE),
        120 => () -> do_plat_dwus(self, line, true),
        123 => () -> do_plat_dwus(self, line, true),
        45 => () -> do_floor(self, line, s -> hgt(s.floorheight) - 8 * FRACUNIT, -1),
        60 => () -> do_floor(self, line, lowest_floor, -1),
        64 => () -> do_floor(self, line, raise_floor_dest, 1),
        70 => () -> do_floor(self, line, highest_floor, -1, FLOORSPEED * 4),
        43 => () -> do_crusher(self, line, CEIL_LOWERTOFLOOR),
        65 => () -> do_floor(self, line, raise_floor_crush_dest, 1, FLOORSPEED, true),
        66 => () -> do_plat_raise(self, line, 24 * FRACUNIT, true),
        67 => () -> do_plat_raise(self, line, 32 * FRACUNIT, true),
        68 => () -> do_plat_raise(self, line, 0, true),
        69 => () -> do_floor(self, line, s -> next_highest_floor(s, hgt(s.floorheight)), 1),
        132 => () -> do_floor(self, line, s -> next_highest_floor(s, hgt(s.floorheight)), 1, FLOORSPEED * 4),
        138 => () -> light_turn_on(self, line, 255),
        139 => () -> light_turn_on(self, line, 35),
    )
    fn = get(tagged, spec, nothing)
    if fn !== nothing
        ok = fn()
        ok && change_switch(self, line, false)
        return ok
    end
    fn = get(retrigger, spec, nothing)
    if fn !== nothing
        ok = fn()
        ok && change_switch(self, line, true)
        return ok
    end
    false
end

function shoot_special(self, line, thing)
    spec = line.special
    if spec == 24
        do_floor(self, line, raise_floor_dest, 1) && change_switch(self, line, false)
    elseif spec == 46
        do_door(self, line, VLD_OPEN, false)
        change_switch(self, line, true)
    elseif spec == 47
        do_plat_raise(self, line, 0, true) && change_switch(self, line, false)
    end
    nothing
end

function teleport(self, line, side, thing)
    (side == 1 || has(thing.flags, MF_MISSILE)) && return false
    tag = line.tag
    for (i, sector) in enumerate(self.world.sectors)
        sector.tag == tag || continue
        for dest in self.world.mobjs
            dest.doomednum == 14 || continue
            dest_sector = point_in_subsector(self.world, dest.x, dest.y).sector
            (dest_sector === sector || dest_sector.i_sector == i - 1) || continue
            thing.momx = 0
            thing.momy = 0
            thing.momz = 0
            unset_thing_position!(self.world, thing)
            thing.x = dest.x
            thing.y = dest.y
            ss = point_in_subsector(self.world, thing.x, thing.y)
            thing.floorz = hgt(ss.sector.floorheight)
            thing.ceilingz = hgt(ss.sector.ceilingheight)
            thing.z = thing.floorz
            thing.angle = dest.angle
            set_thing_position!(self.world, thing)
            if thing.player !== nothing
                thing.player.viewz = thing.z + thing.player.viewheight
            end
            hear(self, "telept")
            mark!(self)
            return true
        end
    end
    false
end

function cross_special(self, line, side, thing)
    spec = line.special
    if spec == 52
        self.exit_requested = true
        return
    end
    if spec == 124
        self.exit_requested = true
        self.secret_exit = true
        return
    end
    door(dtype, reverse) = do_door(self, line, dtype, reverse)
    floor_up24() = do_floor(self, line, s -> hgt(s.floorheight) + 24 * FRACUNIT, 1)
    floor_next(speed) = do_floor(self, line, s -> next_highest_floor(s, hgt(s.floorheight)), 1, speed === nothing ? FLOORSPEED : speed)
    once = Dict{Int,Function}(
        2 => () -> door(VLD_OPEN, false),
        3 => () -> door(VLD_CLOSE, false),
        4 => () -> door(VLD_NORMAL, false),
        5 => () -> do_floor(self, line, raise_floor_dest, 1),
        6 => () -> do_crusher(self, line, CEIL_FASTCRUSH),
        8 => () -> do_stairs(self, line, 8 * FRACUNIT, fld(FLOORSPEED, 4)),
        10 => () -> do_plat_dwus(self, line, false),
        12 => () -> light_turn_on(self, line, 0),
        13 => () -> light_turn_on(self, line, 255),
        16 => () -> door(VLD_CLOSE30, true),
        17 => () -> start_light_strobing(self, line),
        19 => () -> do_floor(self, line, highest_floor, -1),
        22 => () -> do_plat_raise(self, line, 0, true),
        25 => () -> do_crusher(self, line, CEIL_CRUSHANDRAISE),
        30 => () -> raise_to_texture(self, line),
        35 => () -> light_turn_on(self, line, 35),
        36 => () -> do_floor(self, line, highest_floor, -1, FLOORSPEED * 4),
        37 => () -> lower_and_change(self, line),
        38 => () -> do_floor(self, line, lowest_floor, -1),
        39 => () -> (teleport(self, line, side, thing); true),
        40 => () -> (do_crusher(self, line, CEIL_RAISETOHIGHEST); do_floor(self, line, lowest_floor, -1); true),
        44 => () -> do_crusher(self, line, CEIL_LOWERANDCRUSH),
        53 => () -> do_plat_perpetual(self, line),
        54 => () -> stop_plat(self, line),
        56 => () -> do_floor(self, line, raise_floor_crush_dest, 1, FLOORSPEED, true),
        57 => () -> stop_plat(self, line),
        58 => floor_up24,
        59 => floor_up24,
        100 => () -> do_stairs(self, line, 16 * FRACUNIT, FLOORSPEED * 4),
        104 => () -> turn_tag_lights_off(self, line),
        108 => () -> door(VLD_BLAZERAISE, false),
        109 => () -> door(VLD_BLAZEOPEN, false),
        110 => () -> door(VLD_BLAZECLOSE, false),
        119 => () -> floor_next(nothing),
        121 => () -> do_plat_dwus(self, line, true),
        125 => () -> (thing.player === nothing && teleport(self, line, side, thing); true),
        130 => () -> floor_next(FLOORSPEED * 4),
        141 => () -> do_crusher(self, line, CEIL_SILENTCRUSH),
    )
    again = Dict{Int,Function}(
        72 => () -> do_crusher(self, line, CEIL_LOWERANDCRUSH),
        73 => () -> do_crusher(self, line, CEIL_CRUSHANDRAISE),
        74 => () -> stop_plat(self, line),
        75 => () -> door(VLD_CLOSE, false),
        76 => () -> door(VLD_CLOSE30, true),
        77 => () -> do_crusher(self, line, CEIL_FASTCRUSH),
        79 => () -> light_turn_on(self, line, 35),
        80 => () -> light_turn_on(self, line, 0),
        81 => () -> light_turn_on(self, line, 255),
        82 => () -> do_floor(self, line, lowest_floor, -1),
        83 => () -> do_floor(self, line, highest_floor, -1),
        84 => () -> lower_and_change(self, line),
        86 => () -> door(VLD_OPEN, false),
        87 => () -> do_plat_perpetual(self, line),
        88 => () -> do_plat_dwus(self, line, false),
        89 => () -> stop_plat(self, line),
        90 => () -> door(VLD_NORMAL, false),
        91 => () -> do_floor(self, line, raise_floor_dest, 1),
        92 => floor_up24,
        93 => floor_up24,
        94 => () -> do_floor(self, line, raise_floor_crush_dest, 1, FLOORSPEED, true),
        95 => () -> do_plat_raise(self, line, 0, true),
        96 => () -> raise_to_texture(self, line),
        97 => () -> teleport(self, line, side, thing),
        98 => () -> do_floor(self, line, highest_floor, -1, FLOORSPEED * 4),
        105 => () -> door(VLD_BLAZERAISE, false),
        106 => () -> door(VLD_BLAZEOPEN, false),
        107 => () -> door(VLD_BLAZECLOSE, false),
        120 => () -> do_plat_dwus(self, line, true),
        126 => () -> thing.player === nothing ? teleport(self, line, side, thing) : false,
        128 => () -> floor_next(nothing),
        129 => () -> floor_next(FLOORSPEED * 4),
    )
    fn = get(once, spec, nothing)
    if fn !== nothing
        fn()
        line.special = 0
    else
        fn = get(again, spec, nothing)
        fn !== nothing && fn()
    end
    nothing
end

tag_line(tag) = (tag = tag,)

function do_floor_tag(self, tag, dest_fn, direction, speed=FLOORSPEED, crush=false)
    do_floor(self, tag_line(tag), dest_fn, direction, speed, crush)
end

function do_door_tag(self, tag, dtype)
    do_door(self, tag_line(tag), dtype, false)
end

function raise_to_texture_tag(self, tag)
    raise_to_texture(self, tag_line(tag))
end

end

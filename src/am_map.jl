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
# Automapa. Tab liga. As paredes usam ML_MAPPED.

module Automap

using ..Compat
using ..Player
using ..Tables
using ..VVideo
using ..Wad

export new_automap, start!, stop!, reset_level!, ticker!, drawer!, responder!

const FRACUNIT = 65536
const ANGLETOFINESHIFT = 19
const PLAYER_RADIUS = 16 * FRACUNIT
const SCREENWIDTH = 320
const SCREENHEIGHT = 200
const SBARHEIGHT = 32
const ML_DONTDRAW = 128
const ML_MAPPED = 256
const ML_SECRET = 32
const REDS = 256 - 5 * 16
const REDRANGE = 16
const GREENS = 7 * 16
const GRAYS = 6 * 16
const BROWNS = 4 * 16
const YELLOWS = 256 - 32 + 7
const WHITE = 256 - 47
const BACKGROUND = 0
const WALLCOLORS = REDS
const WALLRANGE = REDRANGE
const TSWALLCOLORS = GRAYS
const FDWALLCOLORS = BROWNS
const CDWALLCOLORS = YELLOWS
const THINGCOLORS = GREENS
const GRIDCOLORS = 104
const XHAIRCOLORS = GRAYS
const INITSCALEMTOF = 13107
const F_PANINC = 4
const M_ZOOMIN = 66846
const M_ZOOMOUT = 64250
const AM_NUMMARKPOINTS = 10
const MAPBLOCKUNITS = 128
const INT_MAX = 2147483647
const OC_LEFT = 1
const OC_RIGHT = 2
const OC_BOTTOM = 4
const OC_TOP = 8

mutable struct Mark
    x::Int
    y::Int
end

mutable struct AutoMap
    active::Bool
    cheating::Int
    grid::Int
    followplayer::Int
    stopped::Bool
    lastlevel::Int
    lastepisode::Int
    bigstate::Int
    lightlev::Int
    amclock::Int
    f_x::Int
    f_y::Int
    f_w::Int
    f_h::Int
    m_x::Int
    m_y::Int
    m_x2::Int
    m_y2::Int
    m_w::Int
    m_h::Int
    min_x::Int
    min_y::Int
    max_x::Int
    max_y::Int
    min_scale_mtof::Int
    max_scale_mtof::Int
    scale_mtof::Int
    scale_ftom::Int
    old_m_x::Int
    old_m_y::Int
    old_m_w::Int
    old_m_h::Int
    f_oldloc_x::Int
    f_oldloc_y::Int
    m_paninc_x::Int
    m_paninc_y::Int
    mtof_zoommul::Int
    ftom_zoommul::Int
    player_arrow::Vector{NTuple{4,Int}}
    thintriangle_guy::Vector{NTuple{4,Int}}
    marknums::Vector{Any}
    markpoints::Vector{Mark}
    markpointnum::Int
    fb::Any
    clip::Vector{Int}
end

idiv(a, b) = fld(Int64(a), Int64(b))

function trunc_div(num, den)
    den == 0 && return 0
    q = Float64(num) / Float64(den)
    q >= 0 ? floor(Int, q) : ceil(Int, q)
end

truncn(n) = n >= 0 ? floor(Int, n) : ceil(Int, n)

aline(ax, ay, bx, by) = (ax, ay, bx, by)

function player_arrow()
    n_r = truncn((8 * PLAYER_RADIUS) / 7)
    q = idiv(n_r, 4)
    e = idiv(n_r, 8)
    [
        aline(-n_r + e, 0, n_r, 0),
        aline(n_r, 0, n_r - idiv(n_r, 2), q),
        aline(n_r, 0, n_r - idiv(n_r, 2), -q),
        aline(-n_r + e, 0, -n_r - e, q),
        aline(-n_r + e, 0, -n_r - e, -q),
        aline(-n_r + 3 * e, 0, -n_r + e, q),
        aline(-n_r + 3 * e, 0, -n_r + e, -q),
    ]
end

function thin_triangle()
    [
        aline(truncn(-0.5 * FRACUNIT), truncn(-0.7 * FRACUNIT), FRACUNIT, 0),
        aline(FRACUNIT, 0, truncn(-0.5 * FRACUNIT), truncn(0.7 * FRACUNIT)),
        aline(truncn(-0.5 * FRACUNIT), truncn(0.7 * FRACUNIT), truncn(-0.5 * FRACUNIT), truncn(-0.7 * FRACUNIT)),
    ]
end

function new_automap()
    init_tables!()
    AutoMap(
        false, 0, 0, 1, true, -1, -1, 0, 0, 0,
        0, 0, SCREENWIDTH, SCREENHEIGHT - SBARHEIGHT,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        FRACUNIT, FRACUNIT, INITSCALEMTOF, FRACUNIT,
        0, 0, 0, 0, INT_MAX, 0, 0, 0, FRACUNIT, FRACUNIT,
        player_arrow(), thin_triangle(), Any[],
        [Mark(-1, -1) for _ in 1:AM_NUMMARKPOINTS], 0, nothing, zeros(Int, 4),
    )
end

ftom(self, x) = Int(fixed_mul(x * FRACUNIT, self.scale_ftom))
mtof(self, x) = Int(shar(fixed_mul(x, self.scale_mtof), 16))
cxmtof(self, x) = self.f_x + mtof(self, x - self.m_x)
cymtof(self, y) = self.f_y + (self.f_h - mtof(self, y - self.m_y))

function clear_marks!(self)
    for pt in self.markpoints
        pt.x = -1
        pt.y = -1
    end
    self.markpointnum = 0
end

function find_min_max!(self, world)
    self.min_x = INT_MAX
    self.min_y = INT_MAX
    self.max_x = -INT_MAX
    self.max_y = -INT_MAX
    for v in world.vertexes
        vx, vy = Int(v.x), Int(v.y)
        vx < self.min_x && (self.min_x = vx)
        vx > self.max_x && (self.max_x = vx)
        vy < self.min_y && (self.min_y = vy)
        vy > self.max_y && (self.max_y = vy)
    end
    max_w = self.max_x - self.min_x
    max_h = self.max_y - self.min_y
    max_w <= 0 && (max_w = FRACUNIT)
    max_h <= 0 && (max_h = FRACUNIT)
    a = Int(fixed_div(self.f_w * FRACUNIT, max_w))
    b = Int(fixed_div(self.f_h * FRACUNIT, max_h))
    self.min_scale_mtof = a < b ? a : b
    self.max_scale_mtof = Int(fixed_div(self.f_h * FRACUNIT, 2 * PLAYER_RADIUS))
end

function activate_new_scale!(self)
    self.m_x += idiv(self.m_w, 2)
    self.m_y += idiv(self.m_h, 2)
    self.m_w = ftom(self, self.f_w)
    self.m_h = ftom(self, self.f_h)
    self.m_x -= idiv(self.m_w, 2)
    self.m_y -= idiv(self.m_h, 2)
    self.m_x2 = self.m_x + self.m_w
    self.m_y2 = self.m_y + self.m_h
end

function min_out!(self)
    self.scale_mtof = self.min_scale_mtof
    self.scale_ftom = Int(fixed_div(FRACUNIT, self.scale_mtof))
    activate_new_scale!(self)
end

function max_out!(self)
    self.scale_mtof = self.max_scale_mtof
    self.scale_ftom = Int(fixed_div(FRACUNIT, self.scale_mtof))
    activate_new_scale!(self)
end

function level_init!(self, game)
    self.f_x = 0
    self.f_y = 0
    self.f_w = SCREENWIDTH
    self.f_h = SCREENHEIGHT - SBARHEIGHT
    clear_marks!(self)
    find_min_max!(self, game.world)
    self.scale_mtof = Int(fixed_div(self.min_scale_mtof, truncn(0.7 * FRACUNIT)))
    self.scale_mtof > self.max_scale_mtof && (self.scale_mtof = self.min_scale_mtof)
    self.scale_ftom = Int(fixed_div(FRACUNIT, self.scale_mtof))
end

function change_window_loc!(self)
    if self.m_paninc_x != 0 || self.m_paninc_y != 0
        self.followplayer = 0
        self.f_oldloc_x = INT_MAX
    end
    self.m_x += self.m_paninc_x
    self.m_y += self.m_paninc_y
    if self.m_x + idiv(self.m_w, 2) > self.max_x
        self.m_x = self.max_x - idiv(self.m_w, 2)
    elseif self.m_x + idiv(self.m_w, 2) < self.min_x
        self.m_x = self.min_x - idiv(self.m_w, 2)
    end
    if self.m_y + idiv(self.m_h, 2) > self.max_y
        self.m_y = self.max_y - idiv(self.m_h, 2)
    elseif self.m_y + idiv(self.m_h, 2) < self.min_y
        self.m_y = self.min_y - idiv(self.m_h, 2)
    end
    self.m_x2 = self.m_x + self.m_w
    self.m_y2 = self.m_y + self.m_h
end

function init_variables!(self, game)
    self.active = true
    self.f_oldloc_x = INT_MAX
    self.amclock = 0
    self.lightlev = 0
    self.m_paninc_x = 0
    self.m_paninc_y = 0
    self.ftom_zoommul = FRACUNIT
    self.mtof_zoommul = FRACUNIT
    self.m_w = ftom(self, self.f_w)
    self.m_h = ftom(self, self.f_h)
    mo = game.player.mo
    self.m_x = Int(mo.x) - idiv(self.m_w, 2)
    self.m_y = Int(mo.y) - idiv(self.m_h, 2)
    change_window_loc!(self)
    self.old_m_x = self.m_x
    self.old_m_y = self.m_y
    self.old_m_w = self.m_w
    self.old_m_h = self.m_h
end

function load_pics!(self, wadfile)
    empty!(self.marknums)
    for i in 0:9
        n = check_num_for_name(wadfile, "AMMNUM$i")
        push!(self.marknums, n >= 0 ? cache_lump_num(wadfile, n) : nothing)
    end
end

function stop!(self)
    self.active = false
    self.stopped = true
    self.m_paninc_x = 0
    self.m_paninc_y = 0
    self.mtof_zoommul = FRACUNIT
    self.ftom_zoommul = FRACUNIT
    self.bigstate = 0
end

function start!(self, game)
    self.stopped || stop!(self)
    self.stopped = false
    if self.lastlevel != game.mapn || self.lastepisode != game.episode
        level_init!(self, game)
        self.lastlevel = game.mapn
        self.lastepisode = game.episode
    end
    init_variables!(self, game)
    load_pics!(self, game.wad)
    self.active = true
end

function reset_level!(self)
    self.active && stop!(self)
    self.lastlevel = -1
    self.lastepisode = -1
    self.cheating = 0
end

function do_follow!(self, game)
    mo = game.player.mo
    if self.f_oldloc_x != mo.x || self.f_oldloc_y != mo.y
        self.m_x = ftom(self, mtof(self, mo.x)) - idiv(self.m_w, 2)
        self.m_y = ftom(self, mtof(self, mo.y)) - idiv(self.m_h, 2)
        self.m_x2 = self.m_x + self.m_w
        self.m_y2 = self.m_y + self.m_h
        self.f_oldloc_x = Int(mo.x)
        self.f_oldloc_y = Int(mo.y)
    end
end

function change_window_scale!(self)
    self.scale_mtof = Int(fixed_mul(self.scale_mtof, self.mtof_zoommul))
    self.scale_ftom = Int(fixed_div(FRACUNIT, self.scale_mtof))
    if self.scale_mtof < self.min_scale_mtof
        min_out!(self)
    elseif self.scale_mtof > self.max_scale_mtof
        max_out!(self)
    else
        activate_new_scale!(self)
    end
end

function ticker!(self, game)
    self.active || return
    self.amclock += 1
    self.followplayer != 0 && do_follow!(self, game)
    self.ftom_zoommul != FRACUNIT && change_window_scale!(self)
    (self.m_paninc_x != 0 || self.m_paninc_y != 0) && change_window_loc!(self)
    nothing
end

function clear_fb!(self)
    fb = self.fb
    for y in 0:self.f_h - 1
        row = y * self.f_w
        for x in 0:self.f_w - 1
            fb[row + x + 1] = UInt8(BACKGROUND)
        end
    end
end

function put_dot!(self, xx, yy, cc)
    if 0 <= xx < self.f_w && 0 <= yy < self.f_h
        self.fb[yy * self.f_w + xx + 1] = UInt8(Int(band(cc, 255)))
    end
end

function draw_fline!(self, x0, y0, x1, y1, color)
    if !(0 <= x0 < self.f_w && 0 <= y0 < self.f_h && 0 <= x1 < self.f_w && 0 <= y1 < self.f_h)
        return
    end
    dx = x1 - x0
    ax = abs(dx) * 2
    sx = dx < 0 ? -1 : 1
    dy = y1 - y0
    ay = abs(dy) * 2
    sy = dy < 0 ? -1 : 1
    x, y = x0, y0
    if ax > ay
        d = ay - idiv(ax, 2)
        while true
            put_dot!(self, x, y, color)
            x == x1 && return
            if d >= 0
                y += sy
                d -= ax
            end
            x += sx
            d += ay
        end
    else
        d = ax - idiv(ay, 2)
        while true
            put_dot!(self, x, y, color)
            y == y1 && return
            if d >= 0
                x += sx
                d -= ay
            end
            y += sy
            d += ax
        end
    end
end

function outcode(self, mx, my)
    oc = 0
    my < 0 && (oc |= OC_TOP)
    my >= self.f_h && (oc |= OC_BOTTOM)
    mx < 0 && (oc |= OC_LEFT)
    mx >= self.f_w && (oc |= OC_RIGHT)
    oc
end

function clip_mline!(self, ax, ay, bx, by)
    out1 = ay > self.m_y2 ? OC_TOP : (ay < self.m_y ? OC_BOTTOM : 0)
    out2 = by > self.m_y2 ? OC_TOP : (by < self.m_y ? OC_BOTTOM : 0)
    (out1 & out2) != 0 && return false
    ax < self.m_x && (out1 |= OC_LEFT)
    ax > self.m_x2 && (out1 |= OC_RIGHT)
    bx < self.m_x && (out2 |= OC_LEFT)
    bx > self.m_x2 && (out2 |= OC_RIGHT)
    (out1 & out2) != 0 && return false
    fx0 = cxmtof(self, ax)
    fy0 = cymtof(self, ay)
    fx1 = cxmtof(self, bx)
    fy1 = cymtof(self, by)
    out1 = outcode(self, fx0, fy0)
    out2 = outcode(self, fx1, fy1)
    (out1 & out2) != 0 && return false
    f_w, f_h = self.f_w, self.f_h
    clipped = false
    for _ in 1:8
        if (out1 | out2) == 0
            clipped = true
            break
        end
        outside = out1 != 0 ? out1 : out2
        tmpx, tmpy = 0, 0
        if (outside & OC_TOP) != 0
            dy = fy0 - fy1
            dx = fx1 - fx0
            tmpx = dy != 0 ? fx0 + trunc_div(dx * fy0, dy) : fx0
            tmpy = 0
        elseif (outside & OC_BOTTOM) != 0
            dy = fy0 - fy1
            dx = fx1 - fx0
            tmpx = dy != 0 ? fx0 + trunc_div(dx * (fy0 - f_h), dy) : fx0
            tmpy = f_h - 1
        elseif (outside & OC_RIGHT) != 0
            dy = fy1 - fy0
            dx = fx1 - fx0
            tmpy = dx != 0 ? fy0 + trunc_div(dy * (f_w - 1 - fx0), dx) : fy0
            tmpx = f_w - 1
        else
            dy = fy1 - fy0
            dx = fx1 - fx0
            tmpy = dx != 0 ? fy0 + trunc_div(dy * (-fx0), dx) : fy0
            tmpx = 0
        end
        if outside == out1
            fx0, fy0 = tmpx, tmpy
            out1 = outcode(self, fx0, fy0)
        else
            fx1, fy1 = tmpx, tmpy
            out2 = outcode(self, fx1, fy1)
        end
        (out1 & out2) != 0 && return false
    end
    clipped || return false
    self.clip[1] = fx0
    self.clip[2] = fy0
    self.clip[3] = fx1
    self.clip[4] = fy1
    true
end

function draw_mline!(self, ax, ay, bx, by, color)
    clip_mline!(self, ax, ay, bx, by) && draw_fline!(self, self.clip[1], self.clip[2], self.clip[3], self.clip[4], color)
end

function draw_grid!(self, game)
    block = MAPBLOCKUNITS * FRACUNIT
    orgx = Int(game.world.bmaporgx)
    orgy = Int(game.world.bmaporgy)
    start = self.m_x
    remn = mod(start - orgx, block)
    remn != 0 && (start = start + block - remn)
    endx = self.m_x + self.m_w
    y0, y1 = self.m_y, self.m_y + self.m_h
    x = start
    while x < endx
        draw_mline!(self, x, y0, x, y1, GRIDCOLORS)
        x += block
    end
    start = self.m_y
    remn = mod(start - orgy, block)
    remn != 0 && (start = start + block - remn)
    endy = self.m_y + self.m_h
    x0, x1 = self.m_x, self.m_x + self.m_w
    y = start
    while y < endy
        draw_mline!(self, x0, y, x1, y, GRIDCOLORS)
        y += block
    end
end

function draw_walls!(self, game)
    color = WALLCOLORS + self.lightlev
    powers = game.player.powers
    allmap = powers !== nothing && length(powers) >= 5 && powers[5] != 0
    for lineobj in game.world.lines
        ax, ay = Int(lineobj.v1.x), Int(lineobj.v1.y)
        bx, by = Int(lineobj.v2.x), Int(lineobj.v2.y)
        mapped = Int(band(lineobj.flags, ML_MAPPED)) != 0
        if self.cheating != 0 || mapped
            if Int(band(lineobj.flags, ML_DONTDRAW)) != 0 && self.cheating == 0
            elseif lineobj.backsector === nothing
                draw_mline!(self, ax, ay, bx, by, color)
            elseif lineobj.frontsector === nothing
            elseif lineobj.special == 39
                draw_mline!(self, ax, ay, bx, by, WALLCOLORS + idiv(WALLRANGE, 2))
            elseif Int(band(lineobj.flags, ML_SECRET)) != 0
                draw_mline!(self, ax, ay, bx, by, color)
            elseif lineobj.backsector.floorheight != lineobj.frontsector.floorheight
                draw_mline!(self, ax, ay, bx, by, FDWALLCOLORS + self.lightlev)
            elseif lineobj.backsector.ceilingheight != lineobj.frontsector.ceilingheight
                draw_mline!(self, ax, ay, bx, by, CDWALLCOLORS + self.lightlev)
            elseif self.cheating != 0
                draw_mline!(self, ax, ay, bx, by, TSWALLCOLORS + self.lightlev)
            end
        elseif allmap && Int(band(lineobj.flags, ML_DONTDRAW)) == 0
            draw_mline!(self, ax, ay, bx, by, GRAYS + 3)
        end
    end
end

function rotate(x, y, a)
    n_fine = Int(ushr(as_u32(a), ANGLETOFINESHIFT))
    cs = sine_at(Int(band(n_fine + 2048, 8191)))
    sn = sine_at(n_fine)
    rx = Int(fixed_mul(x, cs)) - Int(fixed_mul(y, sn))
    ry = Int(fixed_mul(x, sn)) + Int(fixed_mul(y, cs))
    rx, ry
end

function draw_line_character!(self, lines, scale, angle, color, x, y)
    for ln in lines
        nax, nay, nbx, nby = ln[1], ln[2], ln[3], ln[4]
        if scale != 0
            nax = Int(fixed_mul(scale, nax))
            nay = Int(fixed_mul(scale, nay))
            nbx = Int(fixed_mul(scale, nbx))
            nby = Int(fixed_mul(scale, nby))
        end
        if angle != 0
            nax, nay = rotate(nax, nay, angle)
            nbx, nby = rotate(nbx, nby, angle)
        end
        draw_mline!(self, nax + x, nay + y, nbx + x, nby + y, color)
    end
end

function draw_marks!(self)
    for i in 1:AM_NUMMARKPOINTS
        pt = self.markpoints[i]
        patch = i <= length(self.marknums) ? self.marknums[i] : nothing
        if pt.x != -1 && patch !== nothing
            fx = cxmtof(self, pt.x)
            fy = cymtof(self, pt.y)
            if self.f_x <= fx && fx <= self.f_w - 5 && self.f_y <= fy && fy <= self.f_h - 6
                draw_patch(self.fb, fx, fy, patch)
            end
        end
    end
end

function drawer!(self, fb, game)
    self.active || return
    self.fb = fb
    clear_fb!(self)
    self.grid != 0 && draw_grid!(self, game)
    draw_walls!(self, game)
    mo = game.player.mo
    draw_line_character!(self, self.player_arrow, 0, mo.angle, WHITE, Int(mo.x), Int(mo.y))
    if self.cheating == 2
        scale = 16 * FRACUNIT
        color = THINGCOLORS + self.lightlev
        for thing in game.world.mobjs
            draw_line_character!(self, self.thintriangle_guy, scale, thing.angle, color, Int(thing.x), Int(thing.y))
        end
    end
    put_dot!(self, idiv(self.f_w, 2), idiv(self.f_h, 2), XHAIRCOLORS)
    draw_marks!(self)
    self.fb = nothing
end

function save_scale!(self)
    self.old_m_x = self.m_x
    self.old_m_y = self.m_y
    self.old_m_w = self.m_w
    self.old_m_h = self.m_h
end

function restore_scale!(self, game)
    self.m_w = self.old_m_w
    self.m_h = self.old_m_h
    if self.followplayer == 0
        self.m_x = self.old_m_x
        self.m_y = self.old_m_y
    else
        mo = game.player.mo
        self.m_x = Int(mo.x) - idiv(self.m_w, 2)
        self.m_y = Int(mo.y) - idiv(self.m_h, 2)
    end
    self.m_x2 = self.m_x + self.m_w
    self.m_y2 = self.m_y + self.m_h
    self.scale_mtof = Int(fixed_div(self.f_w * FRACUNIT, self.m_w))
    self.scale_ftom = Int(fixed_div(FRACUNIT, self.scale_mtof))
end

function add_mark!(self)
    i = self.markpointnum + 1
    self.markpoints[i].x = self.m_x + idiv(self.m_w, 2)
    self.markpoints[i].y = self.m_y + idiv(self.m_h, 2)
    self.markpointnum = mod(self.markpointnum + 1, AM_NUMMARKPOINTS)
end

function responder!(self, key, down, game)
    (game.gamestate != "view" || game.player === nothing || game.world === nothing) && return false
    if down
        if !self.active
            if key == "tab"
                start!(self, game)
                return true
            end
            return false
        end
        if key == "right" || key == "left" || key == "up" || key == "down"
            self.followplayer != 0 && return false
            if key == "right"
                self.m_paninc_x = ftom(self, F_PANINC)
            elseif key == "left"
                self.m_paninc_x = -ftom(self, F_PANINC)
            elseif key == "up"
                self.m_paninc_y = ftom(self, F_PANINC)
            else
                self.m_paninc_y = -ftom(self, F_PANINC)
            end
            return true
        end
        if key == "minus"
            self.mtof_zoommul = M_ZOOMOUT
            self.ftom_zoommul = M_ZOOMIN
            return true
        end
        if key == "equals"
            self.mtof_zoommul = M_ZOOMIN
            self.ftom_zoommul = M_ZOOMOUT
            return true
        end
        if key == "tab"
            stop!(self)
            return true
        end
        if key == "0"
            self.bigstate = self.bigstate != 0 ? 0 : 1
            if self.bigstate != 0
                save_scale!(self)
                min_out!(self)
            else
                restore_scale!(self, game)
            end
            return true
        end
        if key == "f"
            self.followplayer = self.followplayer != 0 ? 0 : 1
            self.f_oldloc_x = INT_MAX
            set_message(game.player, self.followplayer != 0 ? "Follow Mode ON" : "Follow Mode OFF")
            return true
        end
        if key == "g"
            self.grid = self.grid != 0 ? 0 : 1
            set_message(game.player, self.grid != 0 ? "Grid ON" : "Grid OFF")
            return true
        end
        if key == "m"
            set_message(game.player, "Marked Spot $(self.markpointnum)")
            add_mark!(self)
            return true
        end
        if key == "c"
            clear_marks!(self)
            set_message(game.player, "All Marks Cleared")
            return true
        end
        return false
    end
    if self.active
        if (key == "right" || key == "left") && self.followplayer == 0
            self.m_paninc_x = 0
        elseif (key == "up" || key == "down") && self.followplayer == 0
            self.m_paninc_y = 0
        elseif key == "minus" || key == "equals"
            self.mtof_zoommul = FRACUNIT
            self.ftom_zoommul = FRACUNIT
        end
    end
    false
end

end

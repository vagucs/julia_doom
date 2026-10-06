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
# Contagem da intermissao. Um jogador, a partir de wi_stuff.py.

module Wi

using ..Wad
using ..VVideo

export partime, new_wi, ticker!, draw_wi!, done, Board

const SCREENWIDTH = 320
const SCREENHEIGHT = 200
const TICRATE = 35
const WI_TITLEY = 2
const SP_STATSX = 50
const SP_STATSY = 50
const SP_TIMEX = 16
const SP_TIMEY = SCREENHEIGHT - 32
const SHOWNEXTLOCDELAY = 4
const NO_STATE = -1
const STAT_COUNT = 0
const SHOW_NEXT_LOC = 1
const ANIM_ALWAYS = 0
const ANIM_LEVEL = 2

const PARS = [
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 30, 75, 120, 90, 165, 180, 180, 30, 165],
    [0, 90, 90, 90, 120, 90, 360, 240, 30, 170],
    [0, 90, 45, 90, 150, 90, 90, 165, 30, 135],
]
const CPARS = [
    30, 90, 120, 120, 90, 150, 120, 120, 270, 90,
    210, 150, 150, 150, 210, 150, 420, 150, 210, 150,
    240, 150, 180, 150, 150, 300, 330, 420, 300, 180,
    120, 30,
]
const LNODES = [
    [(185, 164), (148, 143), (69, 122), (209, 102), (116, 89), (166, 55), (71, 56), (135, 29), (71, 24)],
    [(254, 25), (97, 50), (188, 64), (128, 78), (214, 92), (133, 130), (208, 136), (148, 140), (235, 158)],
    [(156, 168), (48, 154), (174, 95), (265, 75), (130, 48), (279, 23), (198, 48), (140, 25), (281, 136)],
]
const ANIM_SPEC = [
    [(0, fld(TICRATE, 3), 3, 224, 104, 0), (0, fld(TICRATE, 3), 3, 184, 160, 0), (0, fld(TICRATE, 3), 3, 112, 136, 0), (0, fld(TICRATE, 3), 3, 72, 112, 0), (0, fld(TICRATE, 3), 3, 88, 96, 0), (0, fld(TICRATE, 3), 3, 64, 48, 0), (0, fld(TICRATE, 3), 3, 192, 40, 0), (0, fld(TICRATE, 3), 3, 136, 16, 0), (0, fld(TICRATE, 3), 3, 80, 16, 0), (0, fld(TICRATE, 3), 3, 64, 24, 0)],
    [(2, fld(TICRATE, 3), 1, 128, 136, 1), (2, fld(TICRATE, 3), 1, 128, 136, 2), (2, fld(TICRATE, 3), 1, 128, 136, 3), (2, fld(TICRATE, 3), 1, 128, 136, 4), (2, fld(TICRATE, 3), 1, 128, 136, 5), (2, fld(TICRATE, 3), 1, 128, 136, 6), (2, fld(TICRATE, 3), 1, 128, 136, 7), (0, fld(TICRATE, 3), 3, 192, 144, 8), (2, fld(TICRATE, 3), 1, 128, 136, 8)],
    [(0, fld(TICRATE, 3), 3, 104, 168, 0), (0, fld(TICRATE, 3), 3, 40, 136, 0), (0, fld(TICRATE, 3), 3, 160, 96, 0), (0, fld(TICRATE, 3), 3, 104, 80, 0), (0, fld(TICRATE, 3), 3, 120, 32, 0), (0, fld(TICRATE, 4), 3, 40, 0, 0)],
]

mutable struct Anim
    type::Int
    period::Int
    nanims::Int
    x::Int
    y::Int
    data1::Int
    patches::Vector{Any}
    ctr::Int
    nexttic::Int
end

mutable struct Board
    epsd::Int
    last::Int
    nxt::Int
    maxkills::Int
    maxitems::Int
    maxsecret::Int
    partime::Int
    skills::Int
    sitems::Int
    ssecret::Int
    stime::Int
    didsecret::Bool
    commercial::Bool
end

mutable struct Tally
    game::Any
    wbs::Board
    state::Int
    accelerate::Int
    sp_state::Int
    cnt_kills::Int
    cnt_items::Int
    cnt_secret::Int
    cnt_time::Int
    cnt_par::Int
    cnt_pause::Int
    cnt::Int
    bcnt::Int
    snl_pointeron::Bool
    done::Bool
    anims::Vector{Anim}
    p::Dict{String,Any}
    num::Vector{Any}
    lnames::Vector{Any}
    background::Any
end

function partime(episode, mapn, commercial)
    if commercial
        i = clamp(mapn - 1, 0, length(CPARS) - 1)
        return TICRATE * CPARS[i + 1]
    end
    if 1 <= episode <= 3 && 1 <= mapn <= 9
        return TICRATE * PARS[episode + 1][mapn + 1]
    end
    if 1 <= mapn <= 9
        i = min(mapn, length(CPARS) - 1)
        return TICRATE * CPARS[i + 1]
    end
    TICRATE * 30
end

function lump(w, name)
    n = check_num_for_name(w, name)
    n < 0 && return nothing
    cache_lump_num(w, n)
end

pw(patch) = patch === nothing ? 8 : patch_size(patch)[1]
ph(patch) = patch === nothing ? 16 : patch_size(patch)[2]

function init_animated!(self)
    (self.wbs.commercial || self.wbs.epsd > 2) && return
    for a in self.anims
        a.ctr = -1
        span = max(1, a.period)
        a.nexttic = a.type == ANIM_ALWAYS ? self.bcnt + 1 + rand(0:span - 1) : self.bcnt + 1
    end
    nothing
end

function new_wi(game, wbs::Board)
    w = game.wad
    names = Dict(
        "finished" => "WIF", "entering" => "WIENTER", "kills" => "WIOSTK", "items" => "WIOSTI",
        "sp_secret" => "WISCRT2", "percent" => "WIPCNT", "colon" => "WICOLON", "time" => "WITIME",
        "par" => "WIPAR", "sucks" => "WISUCKS", "minus" => "WIMINUS", "splat" => "WISPLAT",
        "yah0" => "WIURH0", "yah1" => "WIURH1",
    )
    p = Dict{String,Any}(k => lump(w, v) for (k, v) in names)
    num = Any[lump(w, "WINUM$i") for i in 0:9]
    bgname = (wbs.commercial || wbs.epsd == 3) ? "INTERPIC" : "WIMAP$(wbs.epsd)"
    background = lump(w, bgname)
    background === nothing && (background = lump(w, "INTERPIC"))
    nmaps = wbs.commercial ? 32 : 9
    lnames = Any[]
    for i in 0:nmaps - 1
        name = wbs.commercial ? "CWILV$(lpad(string(i), 2, '0'))" : "WILV$(wbs.epsd)$i"
        push!(lnames, lump(w, name))
    end
    anims = Anim[]
    if !wbs.commercial && wbs.epsd < 3
        specs = ANIM_SPEC[wbs.epsd + 1]
        for (j, spec) in enumerate(specs)
            a = Anim(spec[1], spec[2], spec[3], spec[4], spec[5], spec[6], Any[], -1, 0)
            for i in 0:a.nanims - 1
                if wbs.epsd == 1 && j == 9 && length(anims) >= 5
                    src = anims[5]
                    push!(a.patches, i + 1 <= length(src.patches) ? src.patches[i + 1] : nothing)
                else
                    push!(a.patches, lump(w, "WIA$(wbs.epsd)$(lpad(string(j - 1), 2, '0'))$(lpad(string(i), 2, '0'))"))
                end
            end
            push!(anims, a)
        end
    end
    self = Tally(game, wbs, STAT_COUNT, 0, 1, -1, -1, -1, -1, -1, TICRATE, 0, 0, false, false, anims, p, num, lnames, background)
    init_animated!(self)
    self
end

function update_animated!(self)
    (self.wbs.commercial || self.wbs.epsd > 2) && return
    for (i, a) in enumerate(self.anims)
        self.bcnt == a.nexttic || continue
        if a.type == ANIM_ALWAYS
            a.ctr += 1
            a.ctr >= a.nanims && (a.ctr = 0)
            a.nexttic = self.bcnt + a.period
        elseif a.type == ANIM_LEVEL
            if !(self.state == STAT_COUNT && i == 8) && self.wbs.nxt == a.data1
                a.ctr += 1
                a.ctr == a.nanims && (a.ctr -= 1)
                a.nexttic = self.bcnt + a.period
            end
        end
    end
end

function check_accelerate!(self)
    menu = self.game.menu
    menu !== nothing && menu.active && return
    held = self.game.held
    held === nothing && return
    attack = get(held, "ctrl", false)
    use = get(held, "space", false) || get(held, "e", false)
    enter = get(held, "return", false)
    p = self.game.player
    if p === nothing
        (attack || use || enter) && (self.accelerate = 1)
        return
    end
    if attack
        p.attackdown || (self.accelerate = 1)
        p.attackdown = true
    else
        p.attackdown = false
    end
    if use || enter
        p.usedown || (self.accelerate = 1)
        p.usedown = true
    elseif !use
        p.usedown = false
    end
    nothing
end

function init_show_next!(self)
    self.state = SHOW_NEXT_LOC
    self.accelerate = 0
    self.cnt = SHOWNEXTLOCDELAY * TICRATE
    init_animated!(self)
end

function init_no_state!(self)
    self.state = NO_STATE
    self.accelerate = 0
    self.cnt = 10
end

pct(value, maximum) = fld(value * 100, max(1, maximum))

function bang(self, name)
    f = self.game.start_sound
    f !== nothing && f(name)
    nothing
end

function update_stats!(self)
    w = self.wbs
    update_animated!(self)
    if self.accelerate != 0 && self.sp_state != 10
        self.accelerate = 0
        self.cnt_kills = pct(w.skills, w.maxkills)
        self.cnt_items = pct(w.sitems, w.maxitems)
        self.cnt_secret = pct(w.ssecret, w.maxsecret)
        self.cnt_time = fld(w.stime, TICRATE)
        self.cnt_par = fld(w.partime, TICRATE)
        bang(self, "barexp")
        self.sp_state = 10
        return
    end
    if self.sp_state == 2
        self.cnt_kills += 2
        band3(self) && bang(self, "pistol")
        target = pct(w.skills, w.maxkills)
        if self.cnt_kills >= target
            self.cnt_kills = target
            bang(self, "barexp")
            self.sp_state += 1
        end
    elseif self.sp_state == 4
        self.cnt_items += 2
        band3(self) && bang(self, "pistol")
        target = pct(w.sitems, w.maxitems)
        if self.cnt_items >= target
            self.cnt_items = target
            bang(self, "barexp")
            self.sp_state += 1
        end
    elseif self.sp_state == 6
        self.cnt_secret += 2
        band3(self) && bang(self, "pistol")
        target = pct(w.ssecret, w.maxsecret)
        if self.cnt_secret >= target
            self.cnt_secret = target
            bang(self, "barexp")
            self.sp_state += 1
        end
    elseif self.sp_state == 8
        band3(self) && bang(self, "pistol")
        self.cnt_time += 3
        ttime = fld(w.stime, TICRATE)
        self.cnt_time >= ttime && (self.cnt_time = ttime)
        self.cnt_par += 3
        ptime = fld(w.partime, TICRATE)
        if self.cnt_par >= ptime
            self.cnt_par = ptime
            if self.cnt_time >= ttime
                bang(self, "barexp")
                self.sp_state += 1
            end
        end
    elseif self.sp_state == 10
        if self.accelerate != 0
            bang(self, "wpnup")
            w.commercial ? init_no_state!(self) : init_show_next!(self)
        end
    elseif self.sp_state % 2 != 0
        self.cnt_pause -= 1
        if self.cnt_pause == 0
            self.sp_state += 1
            self.cnt_pause = TICRATE
            self.sp_state == 2 && (self.cnt_kills = 0)
            self.sp_state == 4 && (self.cnt_items = 0)
            self.sp_state == 6 && (self.cnt_secret = 0)
            if self.sp_state == 8
                self.cnt_time = 0
                self.cnt_par = 0
            end
        end
    end
end

band3(self) = (self.bcnt & 3) == 0

function ticker!(self)
    self.bcnt += 1
    if self.bcnt == 1 && self.game.sound !== nothing && hasproperty(self.game.sound, :change_music)
        name = self.wbs.commercial ? "dm2int" : "inter"
        self.game.sound.change_music(name, true)
    end
    check_accelerate!(self)
    if self.state == STAT_COUNT
        update_stats!(self)
    elseif self.state == SHOW_NEXT_LOC
        update_show_next!(self)
    elseif self.state == NO_STATE
        update_no_state!(self)
    end
    nothing
end

function update_show_next!(self)
    update_animated!(self)
    self.cnt -= 1
    if self.cnt == 0 || self.accelerate != 0
        init_no_state!(self)
    else
        self.snl_pointeron = (self.cnt & 31) < 20
    end
end

function update_no_state!(self)
    update_animated!(self)
    self.cnt -= 1
    self.cnt == 0 && (self.done = true)
end

function draw_num(self, fb, x, y, n, digits)
    fontw = self.num[1] === nothing ? 8 : pw(self.num[1])
    if digits < 0
        if n == 0
            digits = 1
        else
            digits = 0
            temp = abs(n)
            while temp != 0
                temp = fld(temp, 10)
                digits += 1
            end
        end
    end
    neg = n < 0
    neg && (n = -n)
    while digits > 0
        digits -= 1
        x -= fontw
        d = n % 10
        self.num[d + 1] !== nothing && draw_patch(fb, x, y, self.num[d + 1])
        n = fld(n, 10)
    end
    if neg && self.p["minus"] !== nothing
        x -= 8
        draw_patch(fb, x, y, self.p["minus"])
    end
    x
end

function draw_percent(self, fb, x, y, value)
    value < 0 && return
    self.p["percent"] !== nothing && draw_patch(fb, x, y, self.p["percent"])
    draw_num(self, fb, x, y, value, -1)
end

function draw_time(self, fb, x, y, t)
    t < 0 && return
    if t > 61 * 59
        self.p["sucks"] !== nothing && draw_patch(fb, x - pw(self.p["sucks"]), y, self.p["sucks"])
        return
    end
    colon = self.p["colon"]
    divn = 1
    while true
        n = fld(t, divn) % 60
        colonw = colon === nothing ? 0 : pw(colon)
        x = draw_num(self, fb, x, y, n, 2) - colonw
        divn *= 60
        if divn == 60 || fld(t, divn) != 0
            colon !== nothing && draw_patch(fb, x, y, colon)
        end
        fld(t, divn) == 0 && break
    end
end

function draw_animated!(self, fb)
    (self.wbs.commercial || self.wbs.epsd > 2) && return
    for a in self.anims
        if 0 <= a.ctr < length(a.patches) && a.patches[a.ctr + 1] !== nothing
            draw_patch(fb, a.x, a.y, a.patches[a.ctr + 1])
        end
    end
end

function draw_bg!(self, fb)
    self.background !== nothing && draw_patch(fb, 0, 0, self.background)
    draw_animated!(self, fb)
end

function draw_lf!(self, fb)
    y = WI_TITLEY
    patch = self.lnames[self.wbs.last + 1]
    if patch !== nothing
        draw_patch(fb, fld(SCREENWIDTH - pw(patch), 2), y, patch)
        y += fld(5 * ph(patch), 4)
    end
    if self.p["finished"] !== nothing
        draw_patch(fb, fld(SCREENWIDTH - pw(self.p["finished"]), 2), y, self.p["finished"])
    end
end

function draw_el!(self, fb)
    y = WI_TITLEY
    if self.p["entering"] !== nothing
        draw_patch(fb, fld(SCREENWIDTH - pw(self.p["entering"]), 2), y, self.p["entering"])
        y += fld(5 * ph(self.p["entering"]), 4)
    end
    patch = self.lnames[self.wbs.nxt + 1]
    patch !== nothing && draw_patch(fb, fld(SCREENWIDTH - pw(patch), 2), y, patch)
end

function draw_on_lnode!(self, fb, n, patches)
    nodes = 1 <= self.wbs.epsd + 1 <= length(LNODES) ? LNODES[self.wbs.epsd + 1] : nothing
    (nodes === nothing || n + 1 > length(nodes)) && return
    node = nodes[n + 1]
    for patch in patches
        patch === nothing && continue
        w, h, left, top = patch_size(patch)
        left_x = node[1] - left
        top_y = node[2] - top
        if left_x >= 0 && left_x + w < SCREENWIDTH && top_y >= 0 && top_y + h < SCREENHEIGHT
            draw_patch(fb, node[1], node[2], patch)
            return
        end
    end
end

function draw_stats!(self, fb)
    draw_bg!(self, fb)
    draw_lf!(self, fb)
    lh = self.num[1] === nothing ? 24 : fld(3 * ph(self.num[1]), 2)
    self.p["kills"] !== nothing && draw_patch(fb, SP_STATSX, SP_STATSY, self.p["kills"])
    draw_percent(self, fb, SCREENWIDTH - SP_STATSX, SP_STATSY, self.cnt_kills)
    self.p["items"] !== nothing && draw_patch(fb, SP_STATSX, SP_STATSY + lh, self.p["items"])
    draw_percent(self, fb, SCREENWIDTH - SP_STATSX, SP_STATSY + lh, self.cnt_items)
    self.p["sp_secret"] !== nothing && draw_patch(fb, SP_STATSX, SP_STATSY + 2 * lh, self.p["sp_secret"])
    draw_percent(self, fb, SCREENWIDTH - SP_STATSX, SP_STATSY + 2 * lh, self.cnt_secret)
    self.p["time"] !== nothing && draw_patch(fb, SP_TIMEX, SP_TIMEY, self.p["time"])
    draw_time(self, fb, fld(SCREENWIDTH, 2) - SP_TIMEX, SP_TIMEY, self.cnt_time)
    if self.wbs.epsd < 3
        self.p["par"] !== nothing && draw_patch(fb, fld(SCREENWIDTH, 2) + SP_TIMEX, SP_TIMEY, self.p["par"])
        draw_time(self, fb, SCREENWIDTH - SP_TIMEX, SP_TIMEY, self.cnt_par)
    end
end

function draw_show_next!(self, fb)
    draw_bg!(self, fb)
    self.state == NO_STATE && (self.snl_pointeron = true)
    if !self.wbs.commercial
        if self.wbs.epsd > 2
            draw_el!(self, fb)
            return
        end
        last = self.wbs.last == 8 ? self.wbs.nxt - 1 : self.wbs.last
        for i in 0:max(0, last + 1) - 1
            draw_on_lnode!(self, fb, i, Any[self.p["splat"]])
        end
        self.wbs.didsecret && draw_on_lnode!(self, fb, 8, Any[self.p["splat"]])
        self.snl_pointeron && draw_on_lnode!(self, fb, self.wbs.nxt, Any[self.p["yah0"], self.p["yah1"]])
    end
    if !self.wbs.commercial || self.wbs.nxt != 30
        draw_el!(self, fb)
    end
end

function draw_wi!(self, fb)
    if self.state == STAT_COUNT
        draw_stats!(self, fb)
    else
        draw_show_next!(self, fb)
    end
    nothing
end

done(self) = self.done

end

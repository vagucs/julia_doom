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
# Sprites da vista, a partir de sprites.py. O quadro e o de spawn.
# Os indices da tela continuam 0-based na conta e somam 1 no vetor.

module Sprites

using ..Compat
using ..Wad
using ..VVideo
using ..RData
using ..World
using ..Render
using ..Tables
import ..Render: point_to_angle

export init_defs!, spawn_things!, draw!, new_mobj, draw_psprite!, weapon_xy

include(joinpath(@__DIR__, "spawn_defs.jl"))

const FRACBITS = 16
const SCREENWIDTH = 320
const PIXELS = 64000
const MF_SHADOW = 262144
const MF_AMBUSH = 32
const MTF_AMBUSH = 8
const MINZ = 4 * 65536
const MAX_SPRITE_FRAMES = 29
const SIL_TOP = 1
const SIL_BOTTOM = 2

const FUZZ_DIR = Int[
    1, -1, 1, -1, 1, 1, -1, 1, 1, -1, 1, 1, 1, -1, 1, 1, 1, -1, -1, -1, -1, 1, -1, -1, 1,
    1, 1, 1, -1, 1, -1, 1, 1, -1, -1, 1, 1, -1, -1, -1, -1, 1, 1, 1, 1, -1, 1, 1, -1, 1,
]

fuzzpos = 1

mutable struct SprFrame
    rotate::Int
    lump::Vector{Int}
    flip::Vector{Int}
end

mutable struct Mobj
    x::Int
    y::Int
    z::Int
    angle::UInt32
    sprite::String
    frame::Int
    flags::Int
    momx::Int
    momy::Int
    momz::Int
    radius::Int
    height::Int
    floorz::Int
    ceilingz::Int
    health::Int
    alive::Bool
    player::Any
    fx::Bool
    tics::Int
    damage::Int
    typ::Int
    blocklinked::Bool
    bnext::Any
    bprev::Any
    bindex::Int
    tmx::Int
    tmy::Int
    doomednum::Int
    reactiontime::Int
    lastlook::Int
    target::Any
    tracer::Any
    movedir::Int
    movecount::Int
    threshold::Int
    istate::Int
    spawnpoint::Any
    easy_skip::Bool
end

function new_mobj(;
    x=0, y=0, z=0, angle=UInt32(0), sprite="", frame=0, flags=0,
    momx=0, momy=0, momz=0, radius=0, height=0,
    floorz=0, ceilingz=0, health=0, alive=true,
    player=nothing, fx=false, tics=0, damage=0, typ=0, doomednum=0,
    reactiontime=0, lastlook=0, target=nothing, tracer=nothing,
    movedir=8, movecount=0, threshold=0, istate=0, spawnpoint=nothing,
    easy_skip=false,
)
    Mobj(
        x, y, z, angle, sprite, frame, flags,
        momx, momy, momz, radius, height,
        floorz, ceilingz, health, alive,
        player, fx, tics, damage, typ,
        false, nothing, nothing, 0, 0, 0,
        doomednum,
        reactiontime, lastlook, target, tracer, movedir, movecount, threshold, istate, spawnpoint, easy_skip,
    )
end

struct Vis
    flags::Int
    patch::Vector{UInt8}
    w::Int
    scale::Int
    gx::Int
    gy::Int
    gz::Int
    gzt::Int
    texturemid::Int
    x1::Int
    x2::Int
    xiscale::Int
    startfrac::Int
    idx::Int
end

function u32_at(buf::Vector{UInt8}, at::Int)
    i = at + 1
    Int(buf[i]) | (Int(buf[i + 1]) << 8) | (Int(buf[i + 2]) << 16) | (Int(buf[i + 3]) << 24)
end

function blank_frame()
    SprFrame(-1, fill(-1, 8), zeros(Int, 8))
end

function install!(frames, lump, frame, rotation, flipped)
    (frame < 0 || frame >= MAX_SPRITE_FRAMES || rotation < 0 || rotation > 8) && return false
    sf = frames[frame + 1]
    flip = flipped ? 1 : 0
    if rotation == 0
        sf.rotate == 1 && return true
        sf.rotate = 0
        for r in 1:8
            sf.lump[r] = lump
            sf.flip[r] = flip
        end
        return true
    end
    sf.rotate == 0 && return true
    sf.rotate = 1
    if sf.lump[rotation] < 0
        sf.lump[rotation] = lump
        sf.flip[rotation] = flip
    end
    true
end

function init_defs!(res::Resources)
    wad = res.wad
    start = check_num_for_name(wad, "S_START")
    endn = check_num_for_name(wad, "S_END")
    start < 0 && (start = check_num_for_name(wad, "SS_START"))
    endn < 0 && (endn = check_num_for_name(wad, "SS_END"))
    if start >= 0 && endn > start
        first, last = start + 1, endn - 1
    else
        first, last = 0, num_lumps(wad) - 1
    end
    buckets = Dict{String,Vector{Int}}()
    order = String[]
    for lump in first:last
        name = lump_name(wad, lump)
        ncodeunits(name) < 6 && continue
        key = name[1:4]
        if !haskey(buckets, key)
            buckets[key] = Int[]
            push!(order, key)
        end
        push!(buckets[key], lump)
    end
    result = Dict{String,Vector{SprFrame}}()
    for sprname in order
        frames = [blank_frame() for _ in 1:MAX_SPRITE_FRAMES]
        maxframe = -1
        for lump in buckets[sprname]
            name = lump_name(wad, lump)
            frame = Int(codeunit(name, 5)) - Int('A')
            rotation = Int(codeunit(name, 6)) - Int('0')
            if install!(frames, lump, frame, rotation, false) && frame > maxframe
                maxframe = frame
            end
            if ncodeunits(name) >= 8
                ch = codeunit(name, 7)
                if ch >= UInt8('A') && ch <= UInt8(']')
                    frame2 = Int(ch) - Int('A')
                    rotation2 = Int(codeunit(name, 8)) - Int('0')
                    if install!(frames, lump, frame2, rotation2, true) && frame2 > maxframe
                        maxframe = frame2
                    end
                end
            end
        end
        maxframe < 0 && continue
        for frame_i in 0:maxframe
            frames[frame_i + 1].rotate == -1 && (frames[frame_i + 1].rotate = 0)
        end
        result[sprname] = frames[1:maxframe + 1]
    end
    res.sprites = result
    res
end

function lookup(res::Resources, name, ang_to_thing, moangle, frame)
    bank = res.sprites
    bank === nothing && return nothing
    base = ncodeunits(String(name)) >= 4 ? uppercase(String(name)[1:4]) : uppercase(String(name))
    frames = get(bank, base, nothing)
    frames === nothing && return nothing
    fi = Int(band(frame, 32767))
    (fi < 0 || fi + 1 > length(frames)) && return nothing
    sf = frames[fi + 1]
    if sf.rotate != 0
        rot = Int(band(ushr(as_u32(Int64(ang_to_thing) - Int64(moangle) + 2415919104), 29), 7))
        lump = sf.lump[rot + 1]
        flip = sf.flip[rot + 1]
    else
        lump = sf.lump[1]
        flip = sf.flip[1]
    end
    lump < 0 && return nothing
    lump, flip
end

function point_on_seg_side(x, y, line)
    lx = Int(line.v1.x)
    ly = Int(line.v1.y)
    ldx = Int(line.v2.x) - lx
    ldy = Int(line.v2.y) - ly
    if ldx == 0
        x <= lx && return ldy > 0 ? 1 : 0
        return ldy < 0 ? 1 : 0
    end
    if ldy == 0
        y <= ly && return ldx < 0 ? 1 : 0
        return ldx > 0 ? 1 : 0
    end
    dx = x - lx
    dy = y - ly
    left = Int(fixed_mul(shar(ldy, FRACBITS), dx))
    right = Int(fixed_mul(dy, shar(ldx, FRACBITS)))
    right < left ? 0 : 1
end

function project(r, mo::Mobj)
    tr_x = Int(as_i32(Int(mo.x) - r.viewx))
    tr_y = Int(as_i32(Int(mo.y) - r.viewy))
    gxt = Int(fixed_mul(tr_x, r.viewcos))
    gyt = -Int(fixed_mul(tr_y, r.viewsin))
    tz = gxt - gyt
    tz < MINZ && return nothing
    xscale = Int(fixed_div(r.projection, tz))
    gxt = -Int(fixed_mul(tr_x, r.viewsin))
    gyt = Int(fixed_mul(tr_y, r.viewcos))
    tx = -(gyt + gxt)
    abs(tx) > Int64(tz) * 4 && return nothing
    found = lookup(r.res, mo.sprite, point_to_angle(r, mo.x, mo.y), mo.angle, mo.frame)
    found === nothing && return nothing
    lump, flip = found
    patch = cache_lump_num(r.res.wad, lump)
    pw, _, left, top = patch_size(patch)
    tx -= left * Int(FRACUNIT)
    x1 = Int(shar(Int(r.centerxfrac) + Int(fixed_mul(tx, xscale)), FRACBITS))
    x1 > r.viewwidth && return nothing
    tx += pw * Int(FRACUNIT)
    x2 = Int(shar(Int(r.centerxfrac) + Int(fixed_mul(tx, xscale)), FRACBITS)) - 1
    x2 < 0 && return nothing
    iscale = Int(FRACUNIT)
    xscale != 0 && (iscale = Int(fixed_div(FRACUNIT, xscale)))
    xiscale = iscale
    startfrac = 0
    if flip != 0
        xiscale = -iscale
        startfrac = pw * Int(FRACUNIT) - 1
    end
    vis_x1 = x1 < 0 ? 0 : x1
    vis_x2 = x2 > r.viewwidth - 1 ? r.viewwidth - 1 : x2
    vis_x1 > x1 && (startfrac += xiscale * (vis_x1 - x1))
    detail = r.detailshift
    scale = xscale * (1 << detail)
    mid = Int(mo.z) + top * Int(FRACUNIT) - r.viewz
    Vis(
        mo.flags, patch, pw, scale,
        Int(mo.x), Int(mo.y), Int(mo.z), Int(mo.z) + top * Int(FRACUNIT),
        mid, vis_x1, vis_x2, xiscale, startfrac, 0,
    )
end

function clip_against_walls(r, spr::Vis)
    x1, x2 = spr.x1, spr.x2
    clipbot = fill(-2, SCREENWIDTH)
    cliptop = fill(-2, SCREENWIDTH)
    for n in length(r.drawsegs):-1:1
        ds = r.drawsegs[n]
        (ds.x1 > x2 || ds.x2 < x1) && continue
        (ds.silhouette == 0 && ds.maskedtexturecol === nothing) && continue
        r1 = x1 > ds.x1 ? x1 : ds.x1
        r2 = x2 < ds.x2 ? x2 : ds.x2
        scale = ds.scale2 > ds.scale1 ? ds.scale2 : ds.scale1
        lowscale = ds.scale2 < ds.scale1 ? ds.scale2 : ds.scale1
        in_front = scale < spr.scale || (lowscale < spr.scale && ds.curline !== nothing && point_on_seg_side(spr.gx, spr.gy, ds.curline) == 0)
        if in_front
            ds.maskedtexturecol === nothing || render_masked_seg_range!(r, ds, r1, r2)
        else
            silhouette = ds.silhouette
            spr.gz >= ds.bsilheight && (silhouette = Int(band(silhouette, bnot(SIL_BOTTOM))))
            spr.gzt <= ds.tsilheight && (silhouette = Int(band(silhouette, bnot(SIL_TOP))))
            for x in r1:r2
                i = x - ds.x1
                (i >= 0 && ds.sprtopclip !== nothing && i < ds.clip_count) || continue
                if band(silhouette, SIL_BOTTOM) != 0 && clipbot[x + 1] == -2
                    clipbot[x + 1] = ds.sprbottomclip[i + 1]
                end
                if band(silhouette, SIL_TOP) != 0 && cliptop[x + 1] == -2
                    cliptop[x + 1] = ds.sprtopclip[i + 1]
                end
            end
        end
    end
    viewh = r.viewheight
    for x in x1:x2
        clipbot[x + 1] == -2 && (clipbot[x + 1] = viewh)
        cliptop[x + 1] == -2 && (cliptop[x + 1] = -1)
    end
    cliptop, clipbot
end

function draw_fuzz_pixel!(r, fb, x, y, cm)
    global fuzzpos
    colx = r.detailshift != 0 ? x * 2 : x
    dest = r.ylookup[y + 1] + r.columnofs[colx + 1]
    src = dest + FUZZ_DIR[fuzzpos] * SCREENWIDTH
    fuzzpos += 1
    fuzzpos > length(FUZZ_DIR) && (fuzzpos = 1)
    (src < 0 || src >= PIXELS) && (src = dest)
    pix = src + 1 <= length(fb) && src + 1 >= 1 ? Int(fb[src + 1]) : 0
    val = pix < length(cm) ? Int(cm[pix + 1]) : pix
    if dest >= 0 && dest < PIXELS
        fb[dest + 1] = UInt8(val)
    end
    if r.detailshift != 0 && dest + 1 < PIXELS
        fb[dest + 2] = UInt8(val)
    end
    nothing
end

function draw_one!(r, fb, spr::Vis, clip_walls::Bool=true)
    patch = spr.patch
    patch_w = spr.w
    xiscale = spr.xiscale
    spryscale = spr.scale
    detail = r.detailshift
    y_iscale = abs(xiscale)
    detail > 0 && (y_iscale = fld(y_iscale, 1 << detail))
    y_iscale < 1 && (y_iscale = 1)
    sprtopscreen = Int(r.centeryfrac) - Int(fixed_mul(spr.texturemid, spryscale))
    cliptop, clipbot = if clip_walls
        clip_against_walls(r, spr)
    else
        fill(-1, SCREENWIDTH), fill(r.viewheight, SCREENWIDTH)
    end
    colofs = Vector{Int}(undef, max(1, patch_w))
    for c in 0:(max(1, patch_w) - 1)
        colofs[c + 1] = u32_at(patch, 8 + c * 4)
    end
    fuzz = band(spr.flags, MF_SHADOW) != 0
    cm = if fuzz
        colormap(r.res, 6)
    elseif r.fixedcolormap !== nothing
        r.fixedcolormap
    else
        colormap(r.res, 0)
    end
    cmlen = length(cm)
    plen = length(patch)
    frac = spr.startfrac
    for x in spr.x1:spr.x2
        col = Int(shar(frac, FRACBITS))
        if col >= 0 && col < patch_w
            column = colofs[col + 1]
            while column < plen
                topdelta = patch[column + 1]
                topdelta == 0xff && break
                postlen = Int(patch[column + 2])
                source = column + 3
                topscreen = sprtopscreen + spryscale * topdelta
                bottomscreen = topscreen + spryscale * postlen
                yl = Int(shar(topscreen + Int(FRACUNIT) - 1, FRACBITS))
                yh = Int(shar(bottomscreen - 1, FRACBITS))
                yl <= cliptop[x + 1] && (yl = cliptop[x + 1] + 1)
                yh >= clipbot[x + 1] && (yh = clipbot[x + 1] - 1)
                yl < 0 && (yl = 0)
                yh >= r.viewheight && (yh = r.viewheight - 1)
                if fuzz
                    yl <= 0 && (yl = 1)
                    yh >= r.viewheight - 1 && (yh = r.viewheight - 2)
                end
                if yl <= yh
                    texfrac = Int(fixed_mul(yl * Int(FRACUNIT) - topscreen, y_iscale))
                    texfrac < 0 && (texfrac = 0)
                    for y in yl:yh
                        if fuzz
                            draw_fuzz_pixel!(r, fb, x, y, cm)
                        else
                            idx = Int(shar(texfrac, FRACBITS))
                            if idx >= 0 && idx < postlen
                                pix = Int(patch[source + idx + 1])
                                val = pix < cmlen ? Int(cm[pix + 1]) : pix
                                if r.detailshift != 0
                                    xx = x * 2
                                    off = r.ylookup[y + 1] + r.columnofs[xx + 1]
                                    if off >= 0 && off < PIXELS
                                        fb[off + 1] = UInt8(val)
                                        fb[off + 2] = UInt8(val)
                                    end
                                else
                                    off = r.ylookup[y + 1] + r.columnofs[x + 1]
                                    if off >= 0 && off < PIXELS
                                        fb[off + 1] = UInt8(val)
                                    end
                                end
                            end
                        end
                        texfrac += y_iscale
                    end
                end
                column += postlen + 4
            end
        end
        frac += xiscale
    end
    nothing
end

function skill_bit(skill)
    skill <= 1 && return 1
    skill >= 3 && return 4
    2
end

function spawn_things!(world, skill)
    bit = skill_bit(Int(skill))
    empty!(world.mobjs)
    for mt in world.things
        typ = mt.type
        typ == 11 && continue
        (typ == 1 || typ == 2 || typ == 3 || typ == 4) && continue
        (band(mt.options, bit) != 0 && band(mt.options, 16) == 0) || continue
        rec = get(SPAWN_BY_DOOMED, typ, nothing)
        rec === nothing && continue
        x = mt.x * 65536
        y = mt.y * 65536
        sub = point_in_subsector(world, x, y)
        z = rec.ceiling ? Int(sub.sector.ceilingheight) - rec.height : Int(sub.sector.floorheight)
        flags = rec.flags
        band(mt.options, MTF_AMBUSH) != 0 && (flags = Int(bor(flags, MF_AMBUSH)))
        ang = as_u32(fld(mt.angle, 45) * 536870912)
        push!(world.mobjs, new_mobj(
            x=x, y=y, z=z, angle=ang, sprite=rec.sprite, frame=rec.frame, flags=flags,
            radius=rec.radius, height=rec.height, health=rec.health,
            floorz=Int(sub.sector.floorheight), ceilingz=Int(sub.sector.ceilingheight),
            doomednum=typ,
        ))
    end
    world
end

function draw!(r, world, fb::Vector{UInt8})
    global fuzzpos
    fuzzpos = 1
    r.fb = fb
    vis = Vis[]
    n = 0
    for mo in world.mobjs
        mo isa Mobj || continue
        mo.player !== nothing && continue
        mo.sprite == "" && continue
        item = project(r, mo)
        item === nothing && continue
        n += 1
        push!(vis, Vis(
            item.flags, item.patch, item.w, item.scale, item.gx, item.gy, item.gz, item.gzt,
            item.texturemid, item.x1, item.x2, item.xiscale, item.startfrac, n,
        ))
    end
    sort!(vis, by = v -> (v.scale, v.idx))
    for spr in vis
        draw_one!(r, fb, spr)
    end
    nothing
end

const BASEYCENTER = 100
const WEAPONTOP = 32 * 65536
const FINESINE_LEN = 10240

function weapon_xy(player, leveltime)
    state = player.psprite_state
    if state == "up" || state == "down"
        return 65536, player.psprite_sy
    end
    if state == "atk"
        sy = player.psprite_sy
        (sy === nothing || sy == 0) && (sy = WEAPONTOP)
        return 65536, sy
    end
    bob = player.bob
    angle = Int(band(128 * leveltime, 8191))
    sx = 65536 + Int(fixed_mul(bob, sine_at(mod(angle + fld(FINEANGLES, 4), FINESINE_LEN))))
    angle = Int(band(angle, fld(FINEANGLES, 2) - 1))
    sy = WEAPONTOP + Int(fixed_mul(bob, sine_at(angle)))
    player.psprite_sy = sy
    sx, sy
end

function draw_psprite!(r, fb, patch, sx, sy)
    patch === nothing && return
    w, _, left, top = patch_size(patch)
    pspritescale = r.pspritescale
    pspriteiscale = r.pspriteiscale
    tx = Int(sx) - 160 * 65536
    tx -= left * 65536
    x1 = Int(shar(Int(r.centerxfrac) + Int(fixed_mul(tx, pspritescale)), FRACBITS))
    x1 > r.viewwidth && return
    tx += w * 65536
    x2 = Int(shar(Int(r.centerxfrac) + Int(fixed_mul(tx, pspritescale)), FRACBITS)) - 1
    x2 < 0 && return
    vis_x1 = x1 < 0 ? 0 : x1
    vis_x2 = x2 > r.viewwidth - 1 ? r.viewwidth - 1 : x2
    startfrac = 0
    vis_x1 > x1 && (startfrac += pspriteiscale * (vis_x1 - x1))
    texturemid = BASEYCENTER * 65536 + fld(65536, 2) - (Int(sy) - top * 65536)
    detail = r.detailshift
    spr = Vis(
        0, patch, w, pspritescale * (1 << detail),
        0, 0, 0, 0, texturemid, vis_x1, vis_x2, pspriteiscale, startfrac, 0,
    )
    draw_one!(r, fb, spr, false)
    nothing
end

end

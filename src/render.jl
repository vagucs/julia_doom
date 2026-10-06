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
# Vista, a partir de render.py. BSP, paredes, chao, teto e ceu.
# Os indices do quadro continuam 0-based na conta e somam 1 no vetor.

module Render

using ..Compat
using ..Tables
using ..RData

export new_renderer, set_view_size!, setup_frame!, render_view!, draw_masked!, render_masked_seg_range!

const SCREENWIDTH = 320
const SCREENHEIGHT = 200
const SBARHEIGHT = 32
const PIXELS = SCREENWIDTH * SCREENHEIGHT
const FRACBITS = 16
const FRACUNIT = 65536
const FINEANGLES = 8192
const FINEMASK = 8191
const ANGLETOFINESHIFT = 19
const ANG90 = 1073741824
const ANG180 = UInt32(0x80000000)
const FIELDOFVIEW = 2048
const LIGHTLEVELS = 16
const LIGHTZSHIFT = 20
const MAXLIGHTZ = 128
const LIGHTSCALESHIFT = 12
const MAXLIGHTSCALE = 48
const NUMCOLORMAPS = 32
const NF_SUBSECTOR = 32768
const ML_DONTPEGTOP = 8
const ML_DONTPEGBOTTOM = 16
const ML_MAPPED = 256
const SIL_NONE = 0
const SIL_TOP = 1
const SIL_BOTTOM = 2
const SIL_BOTH = 3
const HEIGHTBITS = 12
const HEIGHTUNIT = 4096
const ANGLETOSKYSHIFT = 22
const SHRT_MAX = 32767
const INT_MAX = 2147483647
const INT_MIN = -2147483647

idiv(n, d) = d == 0 ? 0 : fld(Int64(n), Int64(d))
lsh(n, bits) = bits <= 0 ? Int64(n) : Int64(n) * (Int64(1) << Int(bits))

mutable struct Clip
    first::Int
    last::Int
end

mutable struct Plane
    height::Int
    picnum::Int
    lightlevel::Int
    minx::Int
    maxx::Int
    top::Vector{Int}
    bottom::Vector{Int}
end

mutable struct DrawSeg
    x1::Int
    x2::Int
    scale1::Int
    scale2::Int
    curline::Any
    scalestep::Int
    maskedtexturecol::Union{Nothing,Vector{Int}}
    masked_count::Int
    silhouette::Int
    bsilheight::Int
    tsilheight::Int
    sprtopclip::Union{Nothing,Vector{Int}}
    sprbottomclip::Union{Nothing,Vector{Int}}
    clip_count::Int
end

mutable struct Renderer
    res::Resources
    fb::Vector{UInt8}
    viewwidth::Int
    viewheight::Int
    detailshift::Int
    viewangletox::Vector{Int}
    xtoviewangle::Vector{UInt32}
    yslope::Vector{Int}
    distscale::Vector{Int}
    scalelight::Vector{Vector{Int}}
    zlight::Vector{Vector{Int}}
    walllights::Vector{Int}
    ylookup::Vector{Int}
    columnofs::Vector{Int}
    ceilingclip::Vector{Int}
    floorclip::Vector{Int}
    solidsegs::Vector{Clip}
    visplanes::Vector{Plane}
    drawsegs::Vector{DrawSeg}
    screenblocks::Int
    sized_blocks::Int
    sized_detail::Int
    extralight::Int
    fixedcolormap::Union{Nothing,Vector{UInt8}}
    centerx::Int
    centery::Int
    centerxfrac::Int
    centeryfrac::Int
    projection::Int
    scaledviewwidth::Int
    viewwindowx::Int
    viewwindowy::Int
    pspritescale::Int
    pspriteiscale::Int
    clipangle::UInt32
    viewx::Int
    viewy::Int
    viewz::Int
    viewangle::UInt32
    viewsin::Int
    viewcos::Int
    basexscale::Int
    baseyscale::Int
    newend::Int
    frontsector::Any
    backsector::Any
    curline::Any
    rw_angle1::UInt32
    rw_normalangle::UInt32
    rw_distance::Int
    rw_x::Int
    rw_start::Int
    rw_stopx::Int
    rw_scale::Int
    rw_scalestep::Int
    rw_midtexturemid::Int
    rw_toptexturemid::Int
    rw_bottomtexturemid::Int
    rw_offset::Int
    rw_centerangle::UInt32
    worldtop::Int
    worldbottom::Int
    worldhigh::Int
    worldlow::Int
    midtexture::Int
    toptexture::Int
    bottomtexture::Int
    maskedtexture::Bool
    maskedtexturecol::Union{Nothing,Vector{Int}}
    segtextured::Bool
    markfloor::Bool
    markceiling::Bool
    ceilingplane::Union{Nothing,Plane}
    floorplane::Union{Nothing,Plane}
    topstep::Int
    topfrac::Int
    bottomstep::Int
    bottomfrac::Int
    pixhigh::Int
    pixhighstep::Int
    pixlow::Int
    pixlowstep::Int
    dc_x::Int
    dc_yl::Int
    dc_yh::Int
    dc_iscale::Int
    dc_texturemid::Int
    dc_source::Vector{UInt8}
    dc_colormap::Vector{UInt8}
end

function new_renderer(res::Resources)
    init_tables!()
    r = Renderer(
        res, UInt8[],
        SCREENWIDTH, SCREENHEIGHT - SBARHEIGHT, 0,
        zeros(Int, idiv(FINEANGLES, 2)), zeros(UInt32, SCREENWIDTH + 1),
        zeros(Int, SCREENHEIGHT), zeros(Int, SCREENWIDTH),
        [Int[] for _ in 1:LIGHTLEVELS], [Int[] for _ in 1:LIGHTLEVELS],
        Int[], zeros(Int, SCREENHEIGHT), zeros(Int, SCREENWIDTH),
        zeros(Int, SCREENWIDTH), zeros(Int, SCREENWIDTH),
        [Clip(0, 0) for _ in 1:64], Plane[], DrawSeg[],
        10, -1, -1, 0, nothing,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt32(0),
        0, 0, 0, UInt32(0), 0, 0, 0, 0, 0,
        nothing, nothing, nothing,
        UInt32(0), UInt32(0), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt32(0),
        0, 0, 0, 0, 0, 0, 0, false, nothing, false, false, false,
        nothing, nothing, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, UInt8[], UInt8[],
    )
    r.centerx = idiv(r.viewwidth, 2)
    r.centery = idiv(r.viewheight, 2)
    r.centerxfrac = Int(shl(r.centerx, FRACBITS))
    r.centeryfrac = Int(shl(r.centery, FRACBITS))
    r.projection = r.centerxfrac
    for i in 0:SCREENHEIGHT - 1
        r.ylookup[i + 1] = i * SCREENWIDTH
    end
    init_mapping!(r)
    init_lights!(r)
    init_slopes!(r)
    r
end

function span_tables()
    top = fill(255, SCREENWIDTH)
    bottom = zeros(Int, SCREENWIDTH)
    top, bottom
end

function put!(fb::Vector{UInt8}, dest::Int, val::Integer)
    if 0 <= dest < PIXELS
        fb[dest + 1] = UInt8(val)
    end
    nothing
end

function draw_column!(r::Renderer)
    count = r.dc_yh - r.dc_yl
    (count < 0 || r.dc_x < 0 || r.dc_x >= r.viewwidth) && return
    yl = r.dc_yl
    yl < 0 && (yl = 0)
    yl > SCREENHEIGHT - 1 && (yl = SCREENHEIGHT - 1)
    dest2 = -1
    if r.detailshift != 0
        x = Int(shl(r.dc_x, 1))
        (x < 0 || x + 1 >= SCREENWIDTH) && return
        dest = r.ylookup[yl + 1] + r.columnofs[x + 1]
        dest2 = dest + 1
    else
        dest = r.ylookup[yl + 1] + r.columnofs[r.dc_x + 1]
    end
    fracstep = r.dc_iscale
    frac = Int64(r.dc_texturemid) + Int64(r.dc_yl - r.centery) * Int64(fracstep)
    src = r.dc_source
    slen = length(src)
    slen == 0 && return
    cm = r.dc_colormap
    cmlen = length(cm)
    fb = r.fb
    while count >= 0 && dest < PIXELS
        idx = Int(band(shar(frac, FRACBITS), 127))
        pix = Int(src[mod(idx, slen) + 1])
        val = pix < cmlen ? Int(cm[pix + 1]) : pix
        fb[dest + 1] = UInt8(val)
        if dest2 >= 0 && dest2 < PIXELS
            fb[dest2 + 1] = UInt8(val)
        end
        dest += SCREENWIDTH
        dest2 >= 0 && (dest2 += SCREENWIDTH)
        frac = Int64(as_i32(frac + fracstep))
        count -= 1
    end
    nothing
end

function pad128(pixels::Vector{UInt8})
    n = length(pixels)
    n == 128 && return pixels
    if n > 128
        return pixels[1:128]
    end
    buf = zeros(UInt8, 128)
    n == 0 || copyto!(buf, pixels)
    buf
end

function draw_masked_column!(r::Renderer, posts, sprtopscreen, spryscale, mceil, mfloor)
    basemid = r.dc_texturemid
    for post in posts
        pixels = post.pixels
        isempty(pixels) && continue
        topscreen = sprtopscreen + spryscale * post.topdelta
        bottomscreen = topscreen + spryscale * length(pixels)
        yl = Int(shar(topscreen + FRACUNIT - 1, FRACBITS))
        yh = Int(shar(bottomscreen - 1, FRACBITS))
        yh >= mfloor && (yh = mfloor - 1)
        yl <= mceil && (yl = mceil + 1)
        yl < 0 && (yl = 0)
        yh >= r.viewheight && (yh = r.viewheight - 1)
        if yl <= yh
            r.dc_yl = yl
            r.dc_yh = yh
            r.dc_source = pad128(pixels)
            r.dc_texturemid = basemid - Int(shl(post.topdelta, FRACBITS))
            draw_column!(r)
        end
    end
    r.dc_texturemid = basemid
    nothing
end

function render_masked_seg_range!(r::Renderer, ds::DrawSeg, x1::Int, x2::Int)
    (ds.maskedtexturecol === nothing || ds.curline === nothing) && return
    line = ds.curline
    front = line.frontsector
    back = line.backsector
    sidedef = line.sidedef
    texnum = sidedef === nothing ? 0 : sidedef.midtexture
    (texnum == 0 || back === nothing || front === nothing) && return
    lightnum = Int(ushr(front.lightlevel, 4)) + r.extralight
    if line.v1.y == line.v2.y
        lightnum -= 1
    elseif line.v1.x == line.v2.x
        lightnum += 1
    end
    lightnum = clamp(lightnum, 0, LIGHTLEVELS - 1)
    walllights = r.scalelight[lightnum + 1]
    if band(line.linedef.flags, ML_DONTPEGBOTTOM) != 0
        dc_texturemid = max(Int(front.floorheight), Int(back.floorheight))
        dc_texturemid += texture_height(r.res, texnum) - r.viewz
    else
        dc_texturemid = min(Int(front.ceilingheight), Int(back.ceilingheight))
        dc_texturemid -= r.viewz
    end
    dc_texturemid += Int(sidedef.rowoffset)
    spryscale = ds.scale1 + (x1 - ds.x1) * ds.scalestep
    masked = ds.maskedtexturecol
    for dc_x in x1:x2
        i = dc_x - ds.x1
        if i < 0 || i >= ds.masked_count
            spryscale += ds.scalestep
            continue
        end
        tcol = masked[i + 1]
        if tcol != SHRT_MAX
            index = spryscale > 0 ? Int(ushr(spryscale, LIGHTSCALESHIFT)) : 0
            index >= MAXLIGHTSCALE && (index = MAXLIGHTSCALE - 1)
            level = walllights[index + 1]
            r.dc_colormap = r.fixedcolormap === nothing ? colormap(r.res, level) : r.fixedcolormap
            r.dc_x = dc_x
            r.dc_iscale = spryscale == 0 ? 0 : idiv(4294967295, spryscale)
            r.dc_texturemid = dc_texturemid
            sprtopscreen = r.centeryfrac - Int(fixed_mul(dc_texturemid, spryscale))
            mceil = -1
            if ds.sprtopclip !== nothing && i < ds.clip_count
                mceil = ds.sprtopclip[i + 1]
            end
            mfloor = r.viewheight
            if ds.sprbottomclip !== nothing && i < ds.clip_count
                mfloor = ds.sprbottomclip[i + 1]
            end
            draw_masked_column!(r, column_posts(r.res, texnum, tcol), sprtopscreen, spryscale, mceil, mfloor)
            masked[i + 1] = SHRT_MAX
        end
        spryscale += ds.scalestep
    end
    nothing
end

function draw_masked!(r::Renderer)
    for n in length(r.drawsegs):-1:1
        ds = r.drawsegs[n]
        ds.maskedtexturecol === nothing || render_masked_seg_range!(r, ds, ds.x1, ds.x2)
    end
    nothing
end

function draw_planes!(r::Renderer)
    for pl in r.visplanes
        pl.minx > pl.maxx && continue
        if pl.picnum == r.res.skyflatnum
            r.dc_iscale = idiv(9 * FRACUNIT, 10)
            r.dc_colormap = colormap(r.res, 0)
            r.dc_texturemid = 100 * FRACUNIT
            for x in pl.minx:pl.maxx
                yl = pl.top[x + 1]
                yh = pl.bottom[x + 1]
                (yl <= yh && yl < 255) || continue
                ang = Int(ushr(as_u32(Int64(r.viewangle) + Int64(r.xtoviewangle[x + 1])), ANGLETOSKYSHIFT))
                r.dc_x = x
                r.dc_yl = yl
                r.dc_yh = yh
                r.dc_source = get_column(r.res, r.res.skytexture, ang)
                draw_column!(r)
            end
        else
            light = clamp(Int(ushr(pl.lightlevel, 4)) + r.extralight, 0, LIGHTLEVELS - 1)
            planezlight = r.zlight[light + 1]
            flat = flat_pixels(r.res, pl.picnum)
            flatlen = length(flat)
            planeheight = Int(abs_fixed(pl.height - r.viewz))
            planeheight == 0 && continue
            cached_y = -1
            light_index = -1
            cm = UInt8[]
            cmlen = 0
            distance = 0
            x0 = max(pl.minx, 0)
            x1 = min(pl.maxx, r.viewwidth - 1)
            for x in x0:x1
                t1 = pl.top[x + 1]
                b1 = pl.bottom[x + 1]
                (t1 <= b1 && t1 != 255) || continue
                y1 = min(b1, r.viewheight - 1)
                for y in t1:y1
                    if y != cached_y
                        cached_y = y
                        distance = Int(fixed_mul(planeheight, r.yslope[y + 1]))
                    end
                    span = Int(fixed_mul(distance, r.distscale[x + 1]))
                    ang = Int(band(ushr(as_u32(Int64(r.viewangle) + Int64(r.xtoviewangle[x + 1])), ANGLETOFINESHIFT), FINEMASK))
                    ds_xfrac = r.viewx + Int(fixed_mul(sine_at(band(ang + idiv(FINEANGLES, 4), FINEMASK)), span))
                    ds_yfrac = -r.viewy - Int(fixed_mul(sine_at(ang), span))
                    index = Int(ushr(distance, LIGHTZSHIFT))
                    index > MAXLIGHTZ - 1 && (index = MAXLIGHTZ - 1)
                    if index != light_index
                        light_index = index
                        cm = r.fixedcolormap === nothing ? colormap(r.res, planezlight[index + 1]) : r.fixedcolormap
                        cmlen = length(cm)
                    end
                    spot = Int(bor(band(shar(ds_xfrac, 16), 63), band(shar(ds_yfrac, 10), 4032)))
                    pix = 0 <= spot < flatlen ? Int(flat[spot + 1]) : 0
                    val = pix < cmlen ? Int(cm[pix + 1]) : pix
                    if r.detailshift != 0
                        xx = Int(shl(x, 1))
                        off = r.ylookup[y + 1] + r.columnofs[xx + 1]
                        put!(r.fb, off, val)
                        put!(r.fb, off + 1, val)
                    else
                        put!(r.fb, r.ylookup[y + 1] + r.columnofs[x + 1], val)
                    end
                end
            end
        end
    end
    nothing
end

function scale_from_global_angle(r::Renderer, visangle)
    anglea = as_u32(ANG90 + Int64(as_u32(Int64(visangle) - Int64(r.viewangle))))
    angleb = as_u32(ANG90 + Int64(as_u32(Int64(visangle) - Int64(r.rw_normalangle))))
    sinea = sine_at(band(ushr(anglea, ANGLETOFINESHIFT), FINEMASK))
    sineb = sine_at(band(ushr(angleb, ANGLETOFINESHIFT), FINEMASK))
    num = lsh(fixed_mul(r.projection, sineb), r.detailshift)
    den = Int64(fixed_mul(r.rw_distance, sinea))
    scale = Int(64 * FRACUNIT)
    if den > Int64(ushr(num, 16)) && den != 0
        scale = Int(fixed_div(num, den))
        if scale > 64 * FRACUNIT
            scale = 64 * FRACUNIT
        elseif scale < 256
            scale = 256
        end
    end
    scale
end

function render_seg_loop!(r::Renderer)
    texturecolumn = 0
    while r.rw_x < r.rw_stopx
        yl = Int(shar(r.topfrac + HEIGHTUNIT - 1, HEIGHTBITS))
        ceilc = r.ceilingclip[r.rw_x + 1] + 1
        yl < ceilc && (yl = ceilc)
        if r.markceiling && r.ceilingplane !== nothing
            top = r.ceilingclip[r.rw_x + 1] + 1
            bottom = yl - 1
            bottom >= r.floorclip[r.rw_x + 1] && (bottom = r.floorclip[r.rw_x + 1] - 1)
            if top <= bottom
                r.ceilingplane.top[r.rw_x + 1] = top
                r.ceilingplane.bottom[r.rw_x + 1] = bottom
            end
        end
        yh = Int(shar(r.bottomfrac, HEIGHTBITS))
        yh >= r.floorclip[r.rw_x + 1] && (yh = r.floorclip[r.rw_x + 1] - 1)
        if r.markfloor && r.floorplane !== nothing
            top = yh + 1
            bottom = r.floorclip[r.rw_x + 1] - 1
            top <= r.ceilingclip[r.rw_x + 1] && (top = r.ceilingclip[r.rw_x + 1] + 1)
            if top <= bottom
                r.floorplane.top[r.rw_x + 1] = top
                r.floorplane.bottom[r.rw_x + 1] = bottom
            end
        end
        if r.segtextured
            angle = ushr(as_u32(Int64(r.rw_centerangle) + Int64(r.xtoviewangle[r.rw_x + 1])), ANGLETOFINESHIFT)
            tanv = tangent_at(band(angle, idiv(FINEANGLES, 2) - 1))
            texturecolumn = Int(shar(r.rw_offset - Int(fixed_mul(tanv, r.rw_distance)), FRACBITS))
            index = Int(ushr(r.rw_scale, LIGHTSCALESHIFT))
            index >= MAXLIGHTSCALE && (index = MAXLIGHTSCALE - 1)
            r.dc_colormap = r.fixedcolormap === nothing ? colormap(r.res, r.walllights[index + 1]) : r.fixedcolormap
            r.dc_x = r.rw_x
            r.dc_iscale = r.rw_scale == 0 ? 0 : idiv(4294967295, r.rw_scale)
        end
        if r.midtexture != 0
            r.dc_yl = yl
            r.dc_yh = yh
            r.dc_texturemid = r.rw_midtexturemid
            r.dc_source = get_column(r.res, r.midtexture, texturecolumn)
            draw_column!(r)
            r.ceilingclip[r.rw_x + 1] = r.viewheight
            r.floorclip[r.rw_x + 1] = -1
        else
            if r.toptexture != 0
                mid = Int(shar(r.pixhigh, HEIGHTBITS))
                r.pixhigh += r.pixhighstep
                mid >= r.floorclip[r.rw_x + 1] && (mid = r.floorclip[r.rw_x + 1] - 1)
                if mid >= yl
                    r.dc_yl = yl
                    r.dc_yh = mid
                    r.dc_texturemid = r.rw_toptexturemid
                    r.dc_source = get_column(r.res, r.toptexture, texturecolumn)
                    draw_column!(r)
                    r.ceilingclip[r.rw_x + 1] = mid
                else
                    r.ceilingclip[r.rw_x + 1] = yl - 1
                end
            elseif r.markceiling
                r.ceilingclip[r.rw_x + 1] = yl - 1
            end
            if r.bottomtexture != 0
                mid = Int(shar(r.pixlow + HEIGHTUNIT - 1, HEIGHTBITS))
                r.pixlow += r.pixlowstep
                mid <= r.ceilingclip[r.rw_x + 1] && (mid = r.ceilingclip[r.rw_x + 1] + 1)
                if mid <= yh
                    r.dc_yl = mid
                    r.dc_yh = yh
                    r.dc_texturemid = r.rw_bottomtexturemid
                    r.dc_source = get_column(r.res, r.bottomtexture, texturecolumn)
                    draw_column!(r)
                    r.floorclip[r.rw_x + 1] = mid
                else
                    r.floorclip[r.rw_x + 1] = yh + 1
                end
            elseif r.markfloor
                r.floorclip[r.rw_x + 1] = yh + 1
            end
            if r.maskedtexture && r.maskedtexturecol !== nothing
                r.maskedtexturecol[r.rw_x - r.rw_start + 1] = texturecolumn
            end
        end
        r.rw_scale += r.rw_scalestep
        r.topfrac += r.topstep
        r.bottomfrac += r.bottomstep
        r.rw_x += 1
    end
    nothing
end

function point_to_dist(r::Renderer, x, y)
    dx = Int(abs_fixed(Int(x) - r.viewx))
    dy = Int(abs_fixed(Int(y) - r.viewy))
    dy > dx && ((dx, dy) = (dy, dx))
    dx == 0 && return 0
    frac = fixed_div(dy, dx)
    idx = Int(shar(frac, DBITS))
    idx = clamp(idx, 0, 2048)
    ang = ushr(tanto_at(idx) + UInt32(ANG90), ANGLETOFINESHIFT)
    Int(fixed_div(dx, sine_at(band(ang, FINEMASK))))
end

function copy_clip(src::Vector{Int}, start::Int, stop::Int)
    out = Int[]
    for i in start:stop
        push!(out, src[i + 1])
    end
    out
end

function ensure_clip!(r::Renderer, i::Int)
    while length(r.solidsegs) <= i
        push!(r.solidsegs, Clip(0, 0))
    end
    r.solidsegs[i + 1]
end

function push_drawseg!(r::Renderer, start::Int, stop::Int, scale1::Int)
    ds = DrawSeg(
        start, stop, scale1, scale1 + r.rw_scalestep * max(0, stop - start),
        r.curline, r.rw_scalestep, r.maskedtexturecol,
        r.maskedtexturecol === nothing ? 0 : stop - start + 1,
        SIL_NONE, 0, 0, nothing, nothing, 0,
    )
    if r.backsector === nothing
        ds.silhouette = SIL_BOTH
        ds.bsilheight = INT_MAX
        ds.tsilheight = INT_MIN
        width = stop - start + 1
        ds.sprtopclip = fill(r.viewheight, width)
        ds.sprbottomclip = fill(-1, width)
        ds.clip_count = width
    else
        front = r.frontsector
        back = r.backsector
        if Int(front.floorheight) > Int(back.floorheight)
            ds.silhouette = SIL_BOTTOM
            ds.bsilheight = Int(front.floorheight)
        elseif Int(back.floorheight) > r.viewz
            ds.silhouette = SIL_BOTTOM
            ds.bsilheight = INT_MAX
        end
        if Int(front.ceilingheight) < Int(back.ceilingheight)
            ds.silhouette = Int(bor(ds.silhouette, SIL_TOP))
            ds.tsilheight = Int(front.ceilingheight)
        elseif Int(back.ceilingheight) < r.viewz
            ds.silhouette = Int(bor(ds.silhouette, SIL_TOP))
            ds.tsilheight = INT_MIN
        end
        if Int(back.ceilingheight) <= Int(front.floorheight)
            ds.silhouette = Int(bor(ds.silhouette, SIL_BOTTOM))
            ds.bsilheight = INT_MAX
        end
        if Int(back.floorheight) >= Int(front.ceilingheight)
            ds.silhouette = Int(bor(ds.silhouette, SIL_TOP))
            ds.tsilheight = INT_MIN
        end
        ds.sprtopclip = copy_clip(r.ceilingclip, start, stop)
        ds.sprbottomclip = copy_clip(r.floorclip, start, stop)
        ds.clip_count = length(ds.sprtopclip)
        if r.maskedtexture
            if band(ds.silhouette, SIL_TOP) == 0
                ds.silhouette = Int(bor(ds.silhouette, SIL_TOP))
                ds.tsilheight = INT_MIN
            end
            if band(ds.silhouette, SIL_BOTTOM) == 0
                ds.silhouette = Int(bor(ds.silhouette, SIL_BOTTOM))
                ds.bsilheight = INT_MAX
            end
        end
    end
    push!(r.drawsegs, ds)
    nothing
end

function store_wall_range!(r::Renderer, start::Int, stop::Int)
    start > stop && return
    line = r.curline
    linedef = line.linedef
    sidedef = line.sidedef
    sidedef === nothing && return
    linedef.flags = Int(bor(linedef.flags, ML_MAPPED))
    r.rw_normalangle = as_u32(Int64(line.angle) + ANG90)
    offsetangle = as_u32(Int64(r.rw_normalangle) - Int64(r.rw_angle1))
    offsetangle > ANG180 && (offsetangle = as_u32(-Int64(offsetangle)))
    offsetangle > UInt32(ANG90) && (offsetangle = UInt32(ANG90))
    distangle = as_u32(Int64(ANG90) - Int64(offsetangle))
    hyp = point_to_dist(r, line.v1.x, line.v1.y)
    r.rw_distance = Int(fixed_mul(hyp, sine_at(band(ushr(distangle, ANGLETOFINESHIFT), FINEMASK))))
    r.rw_x = start
    r.rw_start = start
    r.rw_stopx = stop + 1
    r.rw_scale = scale_from_global_angle(r, as_u32(Int64(r.viewangle) + Int64(r.xtoviewangle[start + 1])))
    if stop > start
        scale2 = scale_from_global_angle(r, as_u32(Int64(r.viewangle) + Int64(r.xtoviewangle[stop + 1])))
        r.rw_scalestep = idiv(scale2 - r.rw_scale, stop - start)
    else
        r.rw_scalestep = 0
    end
    r.worldtop = Int(r.frontsector.ceilingheight) - r.viewz
    r.worldbottom = Int(r.frontsector.floorheight) - r.viewz
    r.midtexture = 0
    r.toptexture = 0
    r.bottomtexture = 0
    r.maskedtexture = false
    r.maskedtexturecol = nothing
    r.segtextured = false
    if r.backsector === nothing
        r.midtexture = sidedef.midtexture
        r.markfloor = true
        r.markceiling = true
        if band(linedef.flags, ML_DONTPEGBOTTOM) != 0
            vtop = Int(r.frontsector.floorheight) + texture_height(r.res, r.midtexture)
            r.rw_midtexturemid = vtop - r.viewz
        else
            r.rw_midtexturemid = r.worldtop
        end
        r.rw_midtexturemid += Int(sidedef.rowoffset)
    else
        r.worldhigh = Int(r.backsector.ceilingheight) - r.viewz
        r.worldlow = Int(r.backsector.floorheight) - r.viewz
        if r.frontsector.ceilingpic == r.res.skyflatnum && r.backsector.ceilingpic == r.res.skyflatnum
            r.worldtop = r.worldhigh
        end
        r.markfloor = r.worldlow != r.worldbottom ||
            r.backsector.floorpic != r.frontsector.floorpic ||
            r.backsector.lightlevel != r.frontsector.lightlevel
        r.markceiling = r.worldhigh != r.worldtop ||
            r.backsector.ceilingpic != r.frontsector.ceilingpic ||
            r.backsector.lightlevel != r.frontsector.lightlevel
        if Int(r.backsector.ceilingheight) <= Int(r.frontsector.floorheight) ||
           Int(r.backsector.floorheight) >= Int(r.frontsector.ceilingheight)
            r.markceiling = true
            r.markfloor = true
        end
        if r.worldhigh < r.worldtop
            r.toptexture = sidedef.toptexture
            if band(linedef.flags, ML_DONTPEGTOP) != 0
                r.rw_toptexturemid = r.worldtop
            else
                vtop = Int(r.backsector.ceilingheight) + texture_height(r.res, r.toptexture)
                r.rw_toptexturemid = vtop - r.viewz
            end
        end
        if r.worldlow > r.worldbottom
            r.bottomtexture = sidedef.bottomtexture
            if band(linedef.flags, ML_DONTPEGBOTTOM) != 0
                r.rw_bottomtexturemid = r.worldtop
            else
                r.rw_bottomtexturemid = r.worldlow
            end
        end
        r.rw_toptexturemid += Int(sidedef.rowoffset)
        r.rw_bottomtexturemid += Int(sidedef.rowoffset)
        if sidedef.midtexture != 0
            r.maskedtexture = true
            r.maskedtexturecol = fill(SHRT_MAX, stop - start + 1)
        end
    end
    r.segtextured = r.midtexture != 0 || r.toptexture != 0 || r.bottomtexture != 0 || r.maskedtexture
    if r.segtextured
        offsetangle = as_u32(Int64(r.rw_normalangle) - Int64(r.rw_angle1))
        offsetangle > ANG180 && (offsetangle = as_u32(-Int64(offsetangle)))
        r.rw_offset = Int(fixed_mul(hyp, sine_at(band(ushr(offsetangle, ANGLETOFINESHIFT), FINEMASK))))
        if as_u32(Int64(r.rw_normalangle) - Int64(r.rw_angle1)) < ANG180
            r.rw_offset = Int(as_i32(-Int64(r.rw_offset)))
        end
        r.rw_offset += Int(sidedef.textureoffset) + Int(line.offset)
        r.rw_centerangle = as_u32(Int64(ANG90) + Int64(r.viewangle) - Int64(r.rw_normalangle))
    end
    if Int(r.frontsector.floorheight) >= r.viewz
        r.markfloor = false
    end
    if Int(r.frontsector.ceilingheight) <= r.viewz && r.frontsector.ceilingpic != r.res.skyflatnum
        r.markceiling = false
    end
    if r.markceiling
        r.ceilingplane = check_plane!(r, r.ceilingplane, start, stop)
    end
    if r.markfloor
        r.floorplane = check_plane!(r, r.floorplane, start, stop)
    end
    r.worldtop = Int(shar(r.worldtop, 4))
    r.worldbottom = Int(shar(r.worldbottom, 4))
    r.topstep = -Int(fixed_mul(r.rw_scalestep, r.worldtop))
    r.topfrac = Int(shar(r.centeryfrac, 4)) - Int(fixed_mul(r.worldtop, r.rw_scale))
    r.bottomstep = -Int(fixed_mul(r.rw_scalestep, r.worldbottom))
    r.bottomfrac = Int(shar(r.centeryfrac, 4)) - Int(fixed_mul(r.worldbottom, r.rw_scale))
    if r.backsector !== nothing
        r.worldhigh = Int(shar(r.worldhigh, 4))
        r.worldlow = Int(shar(r.worldlow, 4))
        if r.worldhigh < r.worldtop
            r.pixhigh = Int(shar(r.centeryfrac, 4)) - Int(fixed_mul(r.worldhigh, r.rw_scale))
            r.pixhighstep = -Int(fixed_mul(r.rw_scalestep, r.worldhigh))
        end
        if r.worldlow > r.worldbottom
            r.pixlow = Int(shar(r.centeryfrac, 4)) - Int(fixed_mul(r.worldlow, r.rw_scale))
            r.pixlowstep = -Int(fixed_mul(r.rw_scalestep, r.worldlow))
        end
    end
    scale1 = r.rw_scale
    render_seg_loop!(r)
    push_drawseg!(r, start, stop, scale1)
    nothing
end

function crunch_solid!(r::Renderer, start::Int, nexti::Int)
    nexti == start && return
    dest = start + 1
    for i in (nexti + 1):(r.newend - 1)
        r.solidsegs[dest + 1] = r.solidsegs[i + 1]
        dest += 1
    end
    r.newend = dest
    nothing
end

function clip_solid!(r::Renderer, first::Int, last::Int)
    first > last && return
    start = 0
    while start < r.newend && ensure_clip!(r, start).last < first - 1
        start += 1
    end
    if start >= r.newend
        store_wall_range!(r, first, last)
        return
    end
    if first < r.solidsegs[start + 1].first
        if last < r.solidsegs[start + 1].first - 1
            store_wall_range!(r, first, last)
            for i in (r.newend - 1):-1:start
                ensure_clip!(r, i + 1)
                r.solidsegs[i + 2] = r.solidsegs[i + 1]
            end
            r.solidsegs[start + 1] = Clip(first, last)
            r.newend += 1
            return
        end
        store_wall_range!(r, first, r.solidsegs[start + 1].first - 1)
        r.solidsegs[start + 1].first = first
    end
    last <= r.solidsegs[start + 1].last && return
    nexti = start
    while nexti + 1 < r.newend && last >= r.solidsegs[nexti + 2].first - 1
        store_wall_range!(r, r.solidsegs[nexti + 1].last + 1, r.solidsegs[nexti + 2].first - 1)
        nexti += 1
        if last <= r.solidsegs[nexti + 1].last
            r.solidsegs[start + 1].last = r.solidsegs[nexti + 1].last
            crunch_solid!(r, start, nexti)
            return
        end
    end
    store_wall_range!(r, r.solidsegs[nexti + 1].last + 1, last)
    r.solidsegs[start + 1].last = last
    crunch_solid!(r, start, nexti)
    nothing
end

function clip_pass!(r::Renderer, first::Int, last::Int)
    first > last && return
    start = 0
    while start < r.newend && ensure_clip!(r, start).last < first - 1
        start += 1
    end
    if start >= r.newend
        store_wall_range!(r, first, last)
        return
    end
    if first < r.solidsegs[start + 1].first
        if last < r.solidsegs[start + 1].first - 1
            store_wall_range!(r, first, last)
            return
        end
        store_wall_range!(r, first, r.solidsegs[start + 1].first - 1)
    end
    last <= r.solidsegs[start + 1].last && return
    nexti = start
    while nexti + 1 < r.newend && last >= r.solidsegs[nexti + 2].first - 1
        store_wall_range!(r, r.solidsegs[nexti + 1].last + 1, r.solidsegs[nexti + 2].first - 1)
        nexti += 1
        last <= r.solidsegs[nexti + 1].last && return
    end
    store_wall_range!(r, r.solidsegs[nexti + 1].last + 1, last)
    nothing
end

function point_to_angle(r::Renderer, x, y)
    x = Int(as_i32(Int(x) - r.viewx))
    y = Int(as_i32(Int(y) - r.viewy))
    x == 0 && y == 0 && return UInt32(0)
    if x >= 0
        if y >= 0
            if x > y
                return tanto_at(slope_div(y, x))
            end
            return as_u32(ANG90 - 1 - Int64(tanto_at(slope_div(x, y))))
        end
        y = -y
        if x > y
            return as_u32(-Int64(tanto_at(slope_div(y, x))))
        end
        return as_u32(3221225472 + Int64(tanto_at(slope_div(x, y))))
    end
    x = -x
    if y >= 0
        if x > y
            return as_u32(Int64(ANG180) - 1 - Int64(tanto_at(slope_div(y, x))))
        end
        return as_u32(ANG90 + Int64(tanto_at(slope_div(x, y))))
    end
    y = -y
    if x > y
        return as_u32(Int64(ANG180) + Int64(tanto_at(slope_div(y, x))))
    end
    as_u32(3221225472 - 1 - Int64(tanto_at(slope_div(x, y))))
end

function point_on_side(x, y, node)
    dx = Int(as_i32(Int(x) - Int(node.x)))
    dy = Int(as_i32(Int(y) - Int(node.y)))
    left = Int(as_i32(shar(node.dy, 16))) * dx
    right = dy * Int(as_i32(shar(node.dx, 16)))
    right >= left ? 1 : 0
end

function add_line!(r::Renderer, line)
    r.curline = line
    angle1 = point_to_angle(r, line.v1.x, line.v1.y)
    angle2 = point_to_angle(r, line.v2.x, line.v2.y)
    span = as_u32(Int64(angle1) - Int64(angle2))
    span >= ANG180 && return
    r.rw_angle1 = angle1
    angle1 = as_u32(Int64(angle1) - Int64(r.viewangle))
    angle2 = as_u32(Int64(angle2) - Int64(r.viewangle))
    tspan = as_u32(Int64(angle1) + Int64(r.clipangle))
    if tspan > as_u32(2 * Int64(r.clipangle))
        tspan = as_u32(Int64(tspan) - 2 * Int64(r.clipangle))
        tspan >= span && return
        angle1 = r.clipangle
    end
    tspan = as_u32(Int64(r.clipangle) - Int64(angle2))
    if tspan > as_u32(2 * Int64(r.clipangle))
        tspan = as_u32(Int64(tspan) - 2 * Int64(r.clipangle))
        tspan >= span && return
        angle2 = as_u32(-Int64(r.clipangle))
    end
    mask = idiv(FINEANGLES, 2) - 1
    x1 = r.viewangletox[Int(band(ushr(as_u32(Int64(angle1) + ANG90), ANGLETOFINESHIFT), mask)) + 1]
    x2 = r.viewangletox[Int(band(ushr(as_u32(Int64(angle2) + ANG90), ANGLETOFINESHIFT), mask)) + 1]
    x1 == x2 && return
    r.backsector = line.backsector
    if r.backsector === nothing
        clip_solid!(r, x1, x2 - 1)
        return
    end
    if Int(r.backsector.ceilingheight) <= Int(r.frontsector.floorheight) ||
       Int(r.backsector.floorheight) >= Int(r.frontsector.ceilingheight)
        clip_solid!(r, x1, x2 - 1)
        return
    end
    clip_pass!(r, x1, x2 - 1)
    nothing
end

function subsector!(r::Renderer, world, num::Int)
    sub = world.subsectors[num + 1]
    r.frontsector = sub.sector
    light = clamp(Int(ushr(r.frontsector.lightlevel, 4)) + r.extralight, 0, LIGHTLEVELS - 1)
    r.walllights = r.scalelight[light + 1]
    r.floorplane = find_plane!(r, Int(r.frontsector.floorheight), r.frontsector.floorpic, r.frontsector.lightlevel)
    r.ceilingplane = find_plane!(r, Int(r.frontsector.ceilingheight), r.frontsector.ceilingpic, r.frontsector.lightlevel)
    line = sub.firstline
    for _ in 1:sub.numlines
        add_line!(r, world.segs[line + 1])
        line += 1
    end
    nothing
end

function render_bsp_node!(r::Renderer, world, bspnum::Int)
    if band(bspnum, NF_SUBSECTOR) != 0 || bspnum < 0
        num = bspnum == -1 ? 0 : Int(band(bspnum, 32767))
        subsector!(r, world, num)
        return
    end
    node = world.nodes[bspnum + 1]
    side = point_on_side(r.viewx, r.viewy, node)
    render_bsp_node!(r, world, node.children[side + 1])
    render_bsp_node!(r, world, node.children[Int(bxor(side, 1)) + 1])
    nothing
end

function clear_clip!(r::Renderer)
    r.solidsegs[1].first = -2147483647
    r.solidsegs[1].last = -1
    r.solidsegs[2].first = r.viewwidth
    r.solidsegs[2].last = 2147483647
    r.newend = 2
    for i in 0:r.viewwidth - 1
        r.floorclip[i + 1] = r.viewheight
        r.ceilingclip[i + 1] = -1
    end
    nothing
end

function find_plane!(r::Renderer, height::Int, picnum::Int, lightlevel::Int)
    if picnum == r.res.skyflatnum
        height = 0
        lightlevel = 0
    end
    for p in r.visplanes
        if p.height == height && p.picnum == picnum && p.lightlevel == lightlevel
            return p
        end
    end
    top, bottom = span_tables()
    p = Plane(height, picnum, lightlevel, r.viewwidth, -1, top, bottom)
    push!(r.visplanes, p)
    p
end

function dup_plane!(r::Renderer, src::Plane, start::Int, stop::Int)
    top, bottom = span_tables()
    p = Plane(src.height, src.picnum, src.lightlevel, start, stop, top, bottom)
    push!(r.visplanes, p)
    p
end

function check_plane!(r::Renderer, pl::Union{Nothing,Plane}, start::Int, stop::Int)
    pl === nothing && return find_plane!(r, 0, 0, 0)
    if start < pl.minx
        intrl, unionl = pl.minx, start
    else
        unionl, intrl = pl.minx, start
    end
    if stop > pl.maxx
        intrh, unionh = pl.maxx, stop
    else
        unionh, intrh = pl.maxx, stop
    end
    x = intrl
    while x <= intrh
        if 0 <= x < SCREENWIDTH && pl.top[x + 1] != 255
            break
        end
        x += 1
    end
    if x > intrh
        pl.minx = unionl
        pl.maxx = unionh
        return pl
    end
    dup_plane!(r, pl, start, stop)
end

function setup_frame!(r::Renderer, x, y, z, angle, extra_light=0, fixedcolormap=0)
    r.viewx = Int(x)
    r.viewy = Int(y)
    r.viewz = Int(z)
    r.viewangle = as_u32(angle)
    r.viewsin = fine_sin(r.viewangle)
    r.viewcos = fine_cos(r.viewangle)
    r.extralight = extra_light
    if fixedcolormap != 0
        r.fixedcolormap = colormap(r.res, fixedcolormap)
    else
        r.fixedcolormap = nothing
    end
    ang = band(ushr(as_u32(Int64(r.viewangle) - ANG90), ANGLETOFINESHIFT), FINEMASK)
    denom = r.centerxfrac == 0 ? 1 : r.centerxfrac
    r.basexscale = Int(fixed_div(sine_at(band(ang + idiv(FINEANGLES, 4), FINEMASK)), denom))
    r.baseyscale = -Int(fixed_div(sine_at(ang), denom))
    nothing
end

function render_view!(r::Renderer, world, fb::Vector{UInt8})
    r.fb = fb
    empty!(r.visplanes)
    empty!(r.drawsegs)
    clear_clip!(r)
    if !isempty(world.nodes)
        render_bsp_node!(r, world, world.numnodes - 1)
    else
        subsector!(r, world, 0)
    end
    draw_planes!(r)
    r
end

function init_mapping!(r::Renderer)
    half = idiv(FINEANGLES, 2)
    resize!(r.viewangletox, half)
    focallength = fixed_div(r.centerxfrac, tangent_at(idiv(FINEANGLES, 4) + idiv(FIELDOFVIEW, 2)))
    for i in 0:half - 1
        ft = tangent_at(i)
        t = if ft > FRACUNIT * 2
            -1
        elseif ft < -FRACUNIT * 2
            r.viewwidth + 1
        else
            clamp(Int(shar(as_i32(r.centerxfrac - Int(fixed_mul(ft, focallength)) + FRACUNIT - 1), FRACBITS)), -1, r.viewwidth + 1)
        end
        r.viewangletox[i + 1] = t
    end
    resize!(r.xtoviewangle, r.viewwidth + 1)
    for x in 0:r.viewwidth
        i = 0
        while i < half && r.viewangletox[i + 1] > x
            i += 1
        end
        r.xtoviewangle[x + 1] = as_u32(Int(shl(i, ANGLETOFINESHIFT)) - ANG90)
    end
    for i in 0:half - 1
        if r.viewangletox[i + 1] == -1
            r.viewangletox[i + 1] = 0
        elseif r.viewangletox[i + 1] == r.viewwidth + 1
            r.viewangletox[i + 1] = r.viewwidth
        end
    end
    r.clipangle = r.xtoviewangle[1]
    nothing
end

function init_lights!(r::Renderer)
    for i in 0:LIGHTLEVELS - 1
        startmap = idiv(((LIGHTLEVELS - 1 - i) * 2) * NUMCOLORMAPS, LIGHTLEVELS)
        zrow = Vector{Int}(undef, MAXLIGHTZ)
        for j in 0:MAXLIGHTZ - 1
            scale = Int(ushr(fixed_div(idiv(SCREENWIDTH, 2) * FRACUNIT, Int(shl(j + 1, LIGHTZSHIFT))), LIGHTSCALESHIFT))
            level = clamp(startmap - idiv(scale, 2), 0, NUMCOLORMAPS - 1)
            zrow[j + 1] = level
        end
        r.zlight[i + 1] = zrow
        srow = Vector{Int}(undef, MAXLIGHTSCALE)
        vw = lsh(r.viewwidth, r.detailshift)
        vw < 1 && (vw = 1)
        for j in 0:MAXLIGHTSCALE - 1
            level = clamp(startmap - fld(Int64(j) * SCREENWIDTH, vw * 2), 0, NUMCOLORMAPS - 1)
            srow[j + 1] = level
        end
        r.scalelight[i + 1] = srow
    end
    nothing
end

function init_slopes!(r::Renderer)
    resize!(r.yslope, max(r.viewheight, 1))
    for i in 0:r.viewheight - 1
        dy = abs(lsh(i - r.centery, FRACBITS) + idiv(FRACUNIT, 2))
        dy < 1 && (dy = 1)
        r.yslope[i + 1] = Int(fixed_div(idiv(lsh(r.viewwidth, r.detailshift), 2) * FRACUNIT, dy))
    end
    resize!(r.distscale, max(r.viewwidth, 1))
    for i in 0:r.viewwidth - 1
        cosadj = Int(abs_fixed(fine_cos(r.xtoviewangle[i + 1])))
        cosadj < 1 && (cosadj = 1)
        r.distscale[i + 1] = Int(fixed_div(FRACUNIT, cosadj))
    end
    nothing
end

function set_view_size!(r::Renderer, blocks::Int, detail::Int)
    blocks = clamp(blocks, 3, 11)
    detail = detail == 0 ? 0 : 1
    if r.sized_blocks == blocks && r.sized_detail == detail
        return
    end
    r.sized_blocks = blocks
    r.sized_detail = detail
    r.screenblocks = blocks
    r.detailshift = detail
    if blocks == 11
        scaled = SCREENWIDTH
        viewheight = SCREENHEIGHT
    else
        scaled = blocks * 32
        viewheight = Int(band(idiv(blocks * 168, 10), bnot(7)))
    end
    r.scaledviewwidth = scaled
    r.viewwidth = Int(ushr(scaled, detail))
    r.viewheight = viewheight
    r.centerx = idiv(r.viewwidth, 2)
    r.centery = idiv(r.viewheight, 2)
    r.centerxfrac = Int(shl(r.centerx, FRACBITS))
    r.centeryfrac = Int(shl(r.centery, FRACBITS))
    r.projection = r.centerxfrac
    r.viewwindowx = Int(ushr(SCREENWIDTH - scaled, 1))
    r.viewwindowy = scaled == SCREENWIDTH ? 0 : Int(ushr(SCREENHEIGHT - SBARHEIGHT - viewheight, 1))
    resize!(r.ylookup, SCREENHEIGHT)
    for i in 0:SCREENHEIGHT - 1
        r.ylookup[i + 1] = (i + r.viewwindowy) * SCREENWIDTH
    end
    resize!(r.columnofs, SCREENWIDTH)
    for i in 0:SCREENWIDTH - 1
        r.columnofs[i + 1] = r.viewwindowx + i
    end
    nclip = max(r.viewwidth, 1)
    resize!(r.ceilingclip, nclip)
    resize!(r.floorclip, nclip)
    fill!(r.ceilingclip, 0)
    fill!(r.floorclip, 0)
    r.pspritescale = idiv(FRACUNIT * r.viewwidth, SCREENWIDTH)
    r.pspriteiscale = idiv(FRACUNIT * SCREENWIDTH, max(1, r.viewwidth))
    init_mapping!(r)
    init_slopes!(r)
    init_lights!(r)
    nothing
end

end

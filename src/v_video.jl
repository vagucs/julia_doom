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
# V_DrawPatch (v_video.py). O framebuffer e Vector{UInt8}, indice 1.
# Os offsets do patch continuam 0-based.

module VVideo

export SCREENWIDTH, SCREENHEIGHT, PIXELS, patch_size, new_fb, draw_patch, plot, draw_line

const SCREENWIDTH = 320
const SCREENHEIGHT = 200
const PIXELS = SCREENWIDTH * SCREENHEIGHT

function i16_at(buf::Vector{UInt8}, at::Int)
    i = at + 1
    v = Int(buf[i]) | (Int(buf[i + 1]) << 8)
    v >= 32768 ? v - 65536 : v
end

function u32_at(buf::Vector{UInt8}, at::Int)
    i = at + 1
    Int(buf[i]) | (Int(buf[i + 1]) << 8) | (Int(buf[i + 2]) << 16) | (Int(buf[i + 3]) << 24)
end

function patch_size(patch::Vector{UInt8})
    i16_at(patch, 0), i16_at(patch, 2), i16_at(patch, 4), i16_at(patch, 6)
end

new_fb() = zeros(UInt8, PIXELS)

function draw_patch(fb::Vector{UInt8}, x::Integer, y::Integer, patch::Vector{UInt8}; flipped::Bool=false)
    w, _, left, top = patch_size(patch)
    desttop = (Int(y) - top) * SCREENWIDTH + (Int(x) - left)
    plen = length(patch)
    for col in 0:(w - 1)
        src_col = flipped ? (w - 1 - col) : col
        column = u32_at(patch, 8 + src_col * 4)
        while column < plen
            topdelta = patch[column + 1]
            topdelta == 0xff && break
            post = Int(patch[column + 2])
            source = column + 3
            dest = desttop + Int(topdelta) * SCREENWIDTH
            for _ in 1:post
                if dest >= 0 && dest < PIXELS && source < plen
                    fb[dest + 1] = patch[source + 1]
                end
                source += 1
                dest += SCREENWIDTH
            end
            column += post + 4
        end
        desttop += 1
    end
    fb
end

function plot(fb::Vector{UInt8}, x::Real, y::Real, color::Integer)
    x = floor(Int, x)
    y = floor(Int, y)
    (x < 0 || y < 0 || x >= SCREENWIDTH || y >= SCREENHEIGHT) && return
    fb[y * SCREENWIDTH + x + 1] = UInt8(color & 0xff)
    nothing
end

function draw_line(fb::Vector{UInt8}, x0::Real, y0::Real, x1::Real, y1::Real, color::Integer)
    x0 = floor(Int, x0 + 0.5)
    y0 = floor(Int, y0 + 0.5)
    x1 = floor(Int, x1 + 0.5)
    y1 = floor(Int, y1 + 0.5)
    dx = abs(x1 - x0)
    dy = abs(y1 - y0)
    sx = x0 >= x1 ? -1 : 1
    sy = y0 >= y1 ? -1 : 1
    err = dx - dy
    guard = dx + dy + 1
    while guard > 0
        plot(fb, x0, y0, color)
        (x0 == x1 && y0 == y1) && return
        e2 = err * 2
        if e2 > -dy
            err -= dy
            x0 += sx
        end
        if e2 < dx
            err += dx
            y0 += sy
        end
        guard -= 1
    end
    nothing
end

end

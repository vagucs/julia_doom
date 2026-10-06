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
# Derretimento da tela. O quadro velho escorre e o novo entra por cima.

module Wipe

export new_wipe, capture_start!, capture_end!, begin_wipe!, tick_wipe!

const SCREENWIDTH = 320
const SCREENHEIGHT = 200
const COLW = 160

mutable struct Melt
    start::Vector{UInt8}
    endfb::Vector{UInt8}
    y::Vector{Int}
    active::Bool
end

new_wipe() = Melt(UInt8[], UInt8[], Int[], false)

capture_start!(self, fb) = (self.start = copy(fb))
capture_end!(self, fb) = (self.endfb = copy(fb))

function copy_span!(dst, src, x0, y0, y1, src_y0)
    rows = y1 - y0
    for row in 0:rows - 1
        s = (src_y0 + row) * SCREENWIDTH + x0 + 1
        d = (y0 + row) * SCREENWIDTH + x0 + 1
        dst[d] = src[s]
        dst[d + 1] = src[s + 1]
    end
    nothing
end

function begin_wipe!(self, fb, randfn=(n -> rand(0:n - 1)))
    if !isempty(self.start)
        fb[1:length(self.start)] .= self.start
    end
    y = Vector{Int}(undef, COLW)
    y[1] = -randfn(16)
    for i in 2:COLW
        ny = y[i - 1] + randfn(3) - 1
        ny > 0 && (ny = 0)
        ny == -16 && (ny = -15)
        y[i] = ny
    end
    self.y = y
    self.active = true
    nothing
end

function tick_wipe!(self, tics, fb)
    h = SCREENHEIGHT
    done = true
    steps = tics < 1 ? 1 : tics
    for _ in 1:steps
        for i in 0:COLW - 1
            yi = self.y[i + 1]
            x0 = i * 2
            if yi < 0
                copy_span!(fb, self.start, x0, 0, h, 0)
                self.y[i + 1] = yi + 1
                done = false
            elseif yi < h
                dy = yi < 16 ? yi + 1 : 8
                yi + dy > h && (dy = h - yi)
                copy_span!(fb, self.endfb, x0, yi, yi + dy, yi)
                yi += dy
                self.y[i + 1] = yi
                remn = h - yi
                remn > 0 && copy_span!(fb, self.start, x0, yi, h, 0)
                done = false
            end
        end
    end
    if done
        if !isempty(self.endfb)
            fb[1:length(self.endfb)] .= self.endfb
        end
        self.active = false
    end
    done
end

end

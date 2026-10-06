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
# finesine, finetangent e tantoangle, a partir de tables.py.

module Tables

using ..Compat

export init_tables!, fine_sin, fine_cos, slope_div, sine_at, tangent_at, tanto_at
export ANG90, DBITS, FINEANGLES, FINEMASK

const FINEANGLES = 8192
const FINEMASK = 8191
const ANGLETOFINESHIFT = 19
const FRACUNIT = 65536
const SLOPERANGE = 2048
const ANG90 = 1073741824
const DBITS = 5

const FINESINE = Int[]
const FINETANGENT = Int[]
const TANTOANGLE = UInt32[]

idiv(n, d) = d == 0 ? 0 : fld(Int64(n), Int64(d))

function init_tables!()
    isempty(FINESINE) || return
    nsin = idiv(FINEANGLES, 4) * 5
    for i in 0:nsin - 1
        a = (i + 0.5) * pi * 2 / FINEANGLES
        push!(FINESINE, trunc(Int, FRACUNIT * sin(a)))
    end
    half = idiv(FINEANGLES, 2)
    quarter = idiv(FINEANGLES, 4)
    for i in 0:half - 1
        a = (i - quarter + 0.5) * pi * 2 / FINEANGLES
        v = FRACUNIT * tan(a)
        iv = 0
        if !isfinite(v) || v >= 2147483647
            iv = 2147483647
        elseif v <= -2147483647
            iv = -2147483647
        else
            iv = trunc(Int, v)
        end
        push!(FINETANGENT, iv)
    end
    for i in 0:SLOPERANGE
        ang = atan(i / SLOPERANGE) / (pi * 2) * 4294967295
        push!(TANTOANGLE, as_u32(trunc(Int, ang)))
    end
    nothing
end

sine_at(i) = FINESINE[Int(i) + 1]
tangent_at(i) = FINETANGENT[Int(i) + 1]
tanto_at(i) = TANTOANGLE[Int(i) + 1]

function fine_sin(angle)
    i = band(ushr(as_u32(angle), ANGLETOFINESHIFT), FINEMASK)
    sine_at(i)
end

function fine_cos(angle)
    i = band(ushr(as_u32(angle), ANGLETOFINESHIFT) + idiv(FINEANGLES, 4), FINEMASK)
    sine_at(i)
end

function slope_div(num, den)
    den < 512 && return SLOPERANGE
    ans = idiv(Int64(num) * 8, Int(ushr(den, 8)))
    ans > SLOPERANGE && return SLOPERANGE
    ans
end

end

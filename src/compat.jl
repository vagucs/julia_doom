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
# Volta de 32 bits, deslocamentos e ponto fixo 16.16 (compat.py).
# Int32 e UInt32 ja envolvem na soma, na subtracao e na multiplicacao.
# Um inteiro solto do Julia e Int64: a conta do jogo passa por as_i32 / as_u32.

module Compat

export FRACBITS, FRACUNIT, FB_PIXELS, new_framebuffer
export as_u32, as_i32, ushr, shar, shl, band, bor, bxor, bnot
export fixed_mul, fixed_div, abs_fixed

const FRACBITS = 16
const FRACUNIT = Int32(65536)
const FB_PIXELS = 320 * 200

"""Framebuffer de 320x200. Um indice da PLAYPAL por byte."""
new_framebuffer() = Vector{UInt8}(undef, FB_PIXELS)

function as_u32(n::Integer)
    UInt32(mod(n, Int128(0x100000000)))
end

as_i32(n::Integer) = reinterpret(Int32, as_u32(n))

function ushr(n::Integer, bits::Integer)
    bits <= 0 && return as_u32(n)
    bits >= 32 && return UInt32(0)
    as_u32(n) >> bits
end

function shar(n::Integer, bits::Integer)
    i = as_i32(n)
    bits <= 0 && return i
    bits >= 31 && return i < 0 ? Int32(-1) : Int32(0)
    i >> bits
end

function shl(n::Integer, bits::Integer)
    bits <= 0 && return as_u32(n)
    bits >= 32 && return UInt32(0)
    as_u32(n) << bits
end

band(a::Integer, b::Integer) = as_u32(a) & as_u32(b)
bor(a::Integer, b::Integer) = as_u32(a) | as_u32(b)
bxor(a::Integer, b::Integer) = as_u32(a) ⊻ as_u32(b)
bnot(a::Integer) = ~as_u32(a)

function fixed_mul(a::Integer, b::Integer)
    prod = Int64(as_i32(a)) * Int64(as_i32(b))
    as_i32(prod >> 16)
end

function fixed_div(a::Integer, b::Integer)
    a = as_i32(a)
    b = as_i32(b)
    b == 0 && return a >= 0 ? typemax(Int32) : typemin(Int32)
    aa = abs(Int64(a))
    ab = abs(Int64(b))
    if (aa >> 14) >= ab
        return xor(Int64(a), Int64(b)) < 0 ? typemin(Int32) : typemax(Int32)
    end
    as_i32(fld(Int64(a) << 16, Int64(b)))
end

function abs_fixed(n::Integer)
    n = as_i32(n)
    n < 0 ? -n : n
end

end

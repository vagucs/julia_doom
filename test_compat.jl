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
# Teste de compat.jl. Sem janela.

include(joinpath(@__DIR__, "src", "compat.jl"))
using .Compat

const F = FRACUNIT

function eq(name, got, want)
    got == want || error("$name got $got ($(typeof(got))) want $want")
end

eq("u-1", as_u32(-1), 0xffffffff)
eq("i800", as_i32(0x80000000), Int32(-2147483648))
eq("iff", as_i32(0xffffffff), Int32(-1))
eq("ushr", ushr(0x80000000, 1), 0x40000000)
eq("ushr32", ushr(0xffffffff, 32), 0)
eq("shar-5", shar(-5, 1), Int32(-3))
eq("shar-4", shar(-4, 1), Int32(-2))
eq("sharhi", shar(0x80000000, 1), Int32(-1073741824))
eq("shar31", shar(-2, 31), Int32(-1))
eq("fm1", fixed_mul(F, F), F)
eq("fm6", fixed_mul(Int32(2) * F, Int32(3) * F), Int32(393216))
eq("fmneg", fixed_mul(Int32(-2) * F, Int32(3) * F), Int32(-393216))
eq("fmm1", fixed_mul(-1, F), Int32(-1))
eq("fmmm", fixed_mul(-1, -1), Int32(0))
eq("fmbig", fixed_mul(typemax(Int32), typemax(Int32)), Int32(-65536))
eq("fd2", fixed_div(F, 2), typemax(Int32))
eq("fdhalf", fixed_div(F, Int32(2) * F), Int32(32768))
eq("fdnhalf", fixed_div(-F, Int32(2) * F), Int32(-32768))
eq("fdn3", fixed_div(-1, 3), Int32(-21846))
eq("fd0", fixed_div(1, 0), typemax(Int32))
eq("fdn0", fixed_div(-1, 0), typemin(Int32))
eq("fdsat", fixed_div(0x40000000, F), typemax(Int32))
eq("fdns", fixed_div(-0x40000000, F), typemin(Int32))
eq("band", band(0xff00, 0x0ff0), 0x0f00)
eq("bor", bor(0xff00, 0x0ff0), 0xfff0)
eq("bxor", bxor(0xff00, 0x0ff0), 0xf0f0)
eq("bnot", bnot(0), 0xffffffff)
eq("bandhi", band(0x80000000, 0x80000000), 0x80000000)
eq("shl31", shl(1, 31), 0x80000000)
eq("shl32", shl(1, 32), 0)
eq("abs", abs_fixed(-F), F)

fb = new_framebuffer()
eq("fb", length(fb), 64000)
eq("fbt", eltype(fb), UInt8)

println("compat ok")

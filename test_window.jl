# Abre, apresenta um quadro e fecha. Sem esperar tecla.

include(joinpath(@__DIR__, "src", "video.jl"))
using .Video

s = init(320, 200, 2, "DOOM")
fb = fill(UInt8(40), 320 * 200)
try
    present(s, fb)
    delay(200)
    n = length(poll(s))
    println("janela ok eventos $n")
finally
    shutdown(s)
end

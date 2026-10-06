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
# MUS do E1M1 e o tiro da pistola batem com o Python. Nao abre janela.

include(joinpath(@__DIR__, "src", "compat.jl"))
include(joinpath(@__DIR__, "src", "wad.jl"))
include(joinpath(@__DIR__, "src", "mus2mid.jl"))
include(joinpath(@__DIR__, "src", "video.jl"))
include(joinpath(@__DIR__, "src", "sound.jl"))
using .Wad
using .Mus2Mid
using .Snd

function main()
    same = mus2mid(Vector{UInt8}("MThdxyz"))
    same == Vector{UInt8}("MThdxyz") || error("MThd")
    mus2mid(Vector{UInt8}("MUS")) === nothing || error("MUS curto")
    decode(UInt8[3, 0, 1, 0, 1, 0, 0, 0], 11025, 1) === nothing || error("DS curto")
    wad = WadFile()
    add_file!(wad, find_iwad())
    mid = mus2mid(cache_lump_name(wad, "D_E1M1"))
    mid === nothing && error("D_E1M1")
    length(mid) == 23334 || error("tamanho $(length(mid))")
    sum(Int.(mid)) == 1468394 || error("soma $(sum(Int.(mid)))")
    String(mid[1:4]) == "MThd" || error("cabecalho")
    mid[end - 7:end] == UInt8[0, 129, 51, 0, 0, 255, 47, 0] || error("fim")
    samples = decode(cache_lump_name(wad, "DSPISTOL"), 11025, 1)
    samples === nothing && error("DSPISTOL")
    length(samples) == 5629 || error("amostras $(length(samples))")
    (samples[1] == -512 && samples[end] == -512) || error("pontas")
    sum(samples) == -2625024 || error("soma ds $(sum(samples))")
    println("som ok midi 23334 pistol 5629")
end

main()

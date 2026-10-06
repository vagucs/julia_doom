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
# Teste do menu. Sem janela.

include(joinpath(@__DIR__, "src", "wad.jl"))
include(joinpath(@__DIR__, "src", "v_video.jl"))
include(joinpath(@__DIR__, "src", "compat.jl"))
include(joinpath(@__DIR__, "src", "video.jl"))
include(joinpath(@__DIR__, "src", "mus2mid.jl"))
include(joinpath(@__DIR__, "src", "sound.jl"))
include(joinpath(@__DIR__, "src", "game.jl"))
include(joinpath(@__DIR__, "src", "menu.jl"))
using .Wad
using .VVideo
using .Snd
using .GameMod
using .Menu

wad = WadFile()
add_file!(wad, find_iwad())
sound = new_sound()
game = new_game(sound)
menu = new_menu(wad, sound, game)
fb = new_fb()

ink() = count(!=(0x00), fb)

responder(menu, "return")
(menu.active && menu.screen == "main") || error("enter nao abriu o menu")
draw(menu, fb)
ink() < 1000 && error("menu principal sem patches")
responder(menu, "return")
menu.screen == "episode" || error("novo jogo foi para $(menu.screen)")
responder(menu, "down")
responder(menu, "return")
(menu.screen == "read1" && menu.message !== nothing) || error("episodio 2 deveria avisar a versao registrada")
responder(menu, "escape")
menu.message === nothing || error("aviso nao fechou")
responder(menu, "backspace")
menu.screen == "main" || error("backspace foi para $(menu.screen)")

menu = new_menu(wad, sound, game)
responder(menu, "return")
responder(menu, "return")
responder(menu, "return")
(menu.screen == "skill" && menu.item_on == 2) || error("skill $(menu.screen) item $(menu.item_on)")
responder(menu, "return")
(game.episode == 1 && game.skill == 2 && game.mapn == 1) || error("escolha $(game.episode) $(game.skill)")
menu.message === nothing && error("sem aviso de skill")
draw(menu, fb)
ink() < 20 && error("aviso de skill sem texto")
menu.message = nothing
menu.screen = "options"
menu.item_on = 3
responder(menu, "down")
menu.item_on == 5 || error("seta nao pulou o item vazio, ficou em $(menu.item_on)")
draw(menu, fb)
menu.screen = "sound"
draw(menu, fb)
menu.screen = "load"
draw(menu, fb)
menu.screen = "read1"
menu.message = nothing
draw(menu, fb)
for _ in 1:8
    ticker(menu)
end
menu.which_skull == 1 || error("caveira nao animou")
println("menu ok episodio $(game.episode) skill $(game.skill)")

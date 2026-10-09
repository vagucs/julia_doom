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
# Titulo, menu, vista, inimigos, barra, intermissao e finale. 35 Hz.

include(joinpath(@__DIR__, "src", "wad.jl"))
include(joinpath(@__DIR__, "src", "v_video.jl"))
include(joinpath(@__DIR__, "src", "compat.jl"))
include(joinpath(@__DIR__, "src", "video.jl"))
include(joinpath(@__DIR__, "src", "keys.jl"))
include(joinpath(@__DIR__, "src", "mus2mid.jl"))
include(joinpath(@__DIR__, "src", "sound.jl"))
include(joinpath(@__DIR__, "src", "game.jl"))
include(joinpath(@__DIR__, "src", "menu.jl"))
include(joinpath(@__DIR__, "src", "world.jl"))
include(joinpath(@__DIR__, "src", "r_data.jl"))
include(joinpath(@__DIR__, "src", "tables.jl"))
include(joinpath(@__DIR__, "src", "render.jl"))
include(joinpath(@__DIR__, "src", "sprites.jl"))
include(joinpath(@__DIR__, "src", "random.jl"))
include(joinpath(@__DIR__, "src", "collision.jl"))
include(joinpath(@__DIR__, "src", "player.jl"))
include(joinpath(@__DIR__, "src", "specials.jl"))
include(joinpath(@__DIR__, "src", "info.jl"))
include(joinpath(@__DIR__, "src", "thinker.jl"))
include(joinpath(@__DIR__, "src", "enemy.jl"))
include(joinpath(@__DIR__, "src", "status.jl"))
include(joinpath(@__DIR__, "src", "wipe.jl"))
include(joinpath(@__DIR__, "src", "wi_stuff.jl"))
include(joinpath(@__DIR__, "src", "am_map.jl"))
include(joinpath(@__DIR__, "src", "cheats.jl"))
include(joinpath(@__DIR__, "src", "finale.jl"))
include(joinpath(@__DIR__, "src", "saveg.jl"))
using .Wad
using .VVideo
using .Video
using .Keys
using .Snd
using .GameMod
using .Menu
using .World
using .RData
using .Render
using .Sprites
using .Rng
using .Collision
using .Player
using .Specials
using .Thinker
using .Enemy
using .Status
using .Wipe
using .Wi
using .Automap
using .Cheats
using .Finale
using .Saveg

const TICRATE = 35
const TICK_MS = 1000 / TICRATE

function take_args(argv)
    iwad = nothing
    files = String[]
    warp = false
    episode, mapn, skill = 1, 1, 2
    show_fps = false
    crt = false
    nomonsters = false
    fastparm = false
    respawnparm = false
    nosound = false
    nomusic = false
    nocheats = false
    novsync = false
    i = 1
    while i <= length(argv)
        a = argv[i]
        if a == "-iwad" && i < length(argv)
            iwad = argv[i + 1]
            i += 2
        elseif a == "-warp" && i + 2 <= length(argv)
            warp = true
            episode = something(tryparse(Int, argv[i + 1]), 1)
            mapn = something(tryparse(Int, argv[i + 2]), 1)
            i += 3
        elseif a == "-skill" && i < length(argv)
            skill = something(tryparse(Int, argv[i + 1]), 2)
            i += 2
        elseif a == "-file"
            i += 1
            while i <= length(argv) && !startswith(argv[i], "-")
                push!(files, argv[i])
                i += 1
            end
        elseif a == "-fps"
            show_fps = true
            i += 1
        elseif a == "-crt"
            crt = true
            i += 1
        elseif a == "-nomonsters"
            nomonsters = true
            i += 1
        elseif a == "-fast"
            fastparm = true
            i += 1
        elseif a == "-respawn"
            respawnparm = true
            i += 1
        elseif a == "-nosound"
            nosound = true
            i += 1
        elseif a == "-nomusic"
            nomusic = true
            i += 1
        elseif a == "-nocheats"
            nocheats = true
            i += 1
        elseif a == "-novsync"
            novsync = true
            i += 1
        elseif endswith(lowercase(a), ".wad") && !startswith(a, "-")
            iwad = a
            i += 1
        else
            i += 1
        end
    end
    (; iwad, files, warp, episode, mapn, skill, show_fps, crt, nomonsters, fastparm, respawnparm, nosound, nomusic, nocheats, novsync)
end

opts = take_args(ARGS)
wad = WadFile()
iwad_path = opts.iwad === nothing ? find_iwad() : opts.iwad
add_file!(wad, iwad_path)
for extra in opts.files
    add_file!(wad, extra)
end
pal = cache_lump_name(wad, "PLAYPAL")
title = cache_lump_name(wad, "TITLEPIC")
res = new_resources(wad)
init!(res)
init_defs!(res)
renderer = new_renderer(res)
sound = new_sound()
game = new_game(sound)
game.wad = wad
game.iwad_path = iwad_path
game.skill = opts.skill
game.episode = opts.episode
game.mapn = opts.mapn
game.nomonsters = opts.nomonsters
game.fastparm = opts.fastparm
game.respawnparm = opts.respawnparm
game.show_fps = opts.show_fps
game.crt = opts.crt
game.nocheats = opts.nocheats
init_sound!(sound, wad)
opts.nosound && (sound.enabled = false)
opts.nomusic && (sound.music_enabled = false)
menu = new_menu(wad, sound, game)
game.menu = menu
game.statusbar = new_status(wad)
game.automap = new_automap()
game.cheatbox = new_cheats()
game.wipe = new_wipe()
held = Dict{String,Bool}()
game.held = held

function to_title(game)
    game.automap !== nothing && stop!(game.automap)
    game.finale = nothing
    game.wi = nothing
    game.wiping = false
    game.gamestate = "title"
    game.carry = nothing
    game.player = nothing
    game.world = nothing
    game.specials = nothing
    play_title_music!(sound)
end

function begin_level(game)
    game.automap !== nothing && reset_level!(game.automap)
    world = new_world()
    setup_level(world, wad, game.episode, game.mapn)
    bind_pics(res, world)
    rng_clear!()
    spec = new_specials(world, res, name -> play(sound, name))
    game.world = world
    game.res = res
    game.specials = spec
    game.damage_mobj = (target, source, damage, inflictor=source) -> Enemy.damage_mobj(game, target, source, damage, inflictor)
    game.use_special = (line, thing, side) -> use_special(spec, line, thing, side)
    game.cross_special = (line, side, thing) -> cross_special(spec, line, side, thing)
    game.shoot_special = (line, thing) -> shoot_special(spec, line, thing)
    game.touch_special = function (special, toucher)
        if take_key!(special, toucher)
            unset_thing_position!(world, special)
        end
    end
    game.noise_alert = noise_alert
    game.fire_missile = spawn_player_missile
    game.start_sound = name -> play(sound, name)
    game.player = nothing
    kills, items = spawn_map!(world, game.skill, game)
    game.totalkills = kills
    game.totalitems = items
    game.totalsecret = count(s -> s.special == 9, world.sectors)
    apply_fast!(game)
    player = game.player
    if game.carry !== nothing && player !== nothing
        apply_carry!(player, game.carry)
        game.carry = nothing
    end
    game.statusbar !== nothing && player !== nothing && Status.reset!(game.statusbar, player)
    set_view_size!(renderer, game.screen_size + 3, game.detail_level)
    game.player = player
    game.leveltime = 0
    game.turnheld = 0
    game.exit_wait = 0
    game.mousex = 0
    game.mousey = 0
    game.mouse_fire = false
    game.gamestate = "view"
    println("mapa $(world.mapname)  linhas $(length(world.lines))  coisas $(length(world.mobjs))")
    play_level_music!(sound, game.episode, game.mapn)
    empty!(sound.voices)
    audio_clear()
end

function begin_exit(game)
    game.gamestate == "view" || return
    spec = game.specials
    (spec === nothing || game.player === nothing || !spec.exit_requested) && return
    game.automap !== nothing && stop!(game.automap)
    secret = spec.secret_exit
    game.was_secret = secret
    commercial = check_num_for_name(wad, "MAP01") >= 0
    p = game.player
    game.carry = capture_carry(p)
    spec.exit_requested = false
    if !commercial && game.mapn == 8
        game.finale = new_finale(game)
        game.gamestate = "finale"
        println("finale")
        return
    end
    if secret
        nxt = 9
    elseif game.mapn == 9
        nxt = (4, 6, 7, 3)[game.episode]
    else
        nxt = game.mapn + 1
    end
    game.pending_map = nxt
    kills = max(1, game.totalkills)
    items = max(1, game.totalitems)
    secrets = max(1, game.totalsecret)
    game.wi = new_wi(game, Board(
        game.episode - 1, game.mapn - 1, nxt - 1, kills, items, secrets,
        partime(game.episode, game.mapn, commercial),
        p.killcount, p.itemcount, p.secretcount, game.leveltime,
        game.mapn == 9 || secret, commercial,
    ))
    game.gamestate = "intermission"
    change_music!(sound, commercial ? "dm2int" : "inter", true)
    println("intermissao E$(game.episode)M$(nxt)")
end

function advance_map(game)
    commercial = check_num_for_name(wad, "MAP01") >= 0
    if commercial && commercial_map(game.mapn, game.was_secret)
        game.finale = new_finale(game)
        game.gamestate = "finale"
        return
    end
    lump = commercial ? "MAP" * lpad(string(game.pending_map), 2, '0') : "E$(game.episode)M$(game.pending_map)"
    if check_num_for_name(wad, lump) < 0
        to_title(game)
        return
    end
    game.mapn = game.pending_map
    begin_level(game)
end

function finish_finale(game)
    action = (game.finale === nothing || game.finale.action == "") ? "title" : game.finale.action
    game.finale = nothing
    if action == "worlddone"
        game.mapn = game.pending_map
        begin_level(game)
        return
    end
    to_title(game)
end

function end_game(game)
    to_title(game)
end

function do_save(game, slot, name)
    label = (name === nothing || name == "") && game.world !== nothing ? game.world.mapname : name
    write_save(game, slot, label === nothing ? "save" : label)
end

function do_load(game, slot)
    ok = load_save(game, slot)
    ok && game.statusbar !== nothing && game.player !== nothing && Status.reset!(game.statusbar, game.player)
    ok
end

game.start_level = begin_level
game.save_game = do_save
game.load_game = do_load
game.slot_desc = (g, slot) -> description(g, slot)[1]
game.end_game = end_game
fb = new_fb()

function paint_view()
    if game.automap !== nothing && game.automap.active
        fill!(fb, 0x00)
        drawer!(game.automap, fb, game)
        game.player !== nothing && draw_status!(game.statusbar, fb, game.player, game.show_messages)
        return
    end
    p = game.player
    mo = p === nothing ? nothing : p.mo
    x = y = ang = extra = cmap = 0
    z = 41 * 65536
    if mo !== nothing
        x, y, z, ang = mo.x, mo.y, p.viewz, mo.angle
        extra, cmap = p.extralight, p.fixedcolormap
    end
    set_view_size!(renderer, game.screen_size + 3, game.detail_level)
    setup_frame!(renderer, x, y, z, ang, extra, cmap)
    fill!(fb, 0x00)
    render_view!(renderer, game.world, fb)
    draw!(renderer, game.world, fb)
    draw_masked!(renderer)
    if p !== nothing && (p.playerstate != Player.PST_DEAD || p.psprite_sy < Player.WEAPONBOTTOM)
        draw_weapon!(renderer, fb, p, game.leveltime)
    end
    if game.player !== nothing && renderer.screenblocks < 11
        draw_status!(game.statusbar, fb, game.player, game.show_messages)
    end
end

function apply_palette()
    paln = 0
    p = game.player
    if p !== nothing && game.gamestate == "view"
        cnt = p.damagecount
        strength = p.powers[2]
        if strength != 0
            bzc = 12 - fld(strength, 64)
            bzc > cnt && (cnt = bzc)
        end
        if cnt != 0
            paln = min(7, fld(cnt + 7, 8)) + 1
        elseif p.bonuscount != 0
            paln = min(3, fld(p.bonuscount + 7, 8)) + 9
        else
            feet = length(p.powers) >= 4 ? p.powers[4] : 0
            (feet > 4 * 32 || (feet % 16) >= 8) && (paln = 13)
        end
    end
    paln == game.st_palette && return
    game.st_palette = paln
    off = paln * 768
    set_palette(screen, pal[off + 1:off + 768])
end

function paint_state()
    if game.gamestate == "view" && game.world !== nothing
        paint_view()
    elseif game.gamestate == "intermission" && game.wi !== nothing
        fill!(fb, 0x00)
        draw_wi!(game.wi, fb)
    elseif game.gamestate == "finale" && game.finale !== nothing
        draw_finale!(game.finale, fb)
    else
        fill!(fb, 0x00)
        draw_patch(fb, 0, 0, title)
    end
end

function draw_fps()
    game.show_fps || return
    text = game.fps_text
    width = text_width(game.statusbar, text)
    x = max(0, SCREENWIDTH - 6 - width)
    draw_text!(game.statusbar, fb, x, 4, text)
end

function redraw()
    if game.wiping
        draw(menu, fb)
        draw_fps()
        apply_palette()
        present(screen, fb)
        return
    end
    prev = game.wipe_state
    need = prev != "" && (prev != game.gamestate || game.force_wipe)
    if prev == "title" && game.gamestate == "view" && !game.force_wipe
        need = false
    end
    game.force_wipe = false
    need && capture_start!(game.wipe, fb)
    paint_state()
    if need
        capture_end!(game.wipe, fb)
        begin_wipe!(game.wipe, fb)
        game.wiping = true
    end
    game.wipe_state = game.gamestate
    draw(menu, fb)
    draw_fps()
    apply_palette()
    present(screen, fb)
end

screen = init(SCREENWIDTH, SCREENHEIGHT, 2, "DOOM"; novsync=opts.novsync)
opts.novsync && println("vsync desligado")
set_crt!(screen, game.crt)
if opts.warp
    begin_level(game)
    game.wipe_state = "view"
else
    play_title_music!(sound)
end
println("Enter abre o menu. Setas andam, Ctrl atira, Espaco usa, Tab e o mapa.")
println("O rato olha e o botao esquerdo atira. Fechar a janela sai.")
try
    set_palette(screen, pal[1:768])
    mouse_live = Ref(false)
    dirty = true
    accum = 0.0
    last = ticks()
    fps_n = 0
    fps_t = last
    while game.running
        for ev in poll(screen)
            if ev.mouse
                if ev.button == 0
                    game.mousex += ev.dx
                    game.mousey -= ev.dy
                elseif ev.button == 1
                    game.mouse_fire = ev.down
                end
            elseif ev.quit
                game.running = false
            else
                key = name_of(ev.sym)
                if key != ""
                    if ev.down && key == "return" && (get(held, "alt", false) || ev.alt)
                        toggle_fullscreen(screen)
                    elseif ev.down
                        block_menu = (game.gamestate == "intermission" || game.gamestate == "finale") && !menu.active && key == "return"
                        used = false
                        if !block_menu && responder(menu, key)
                            used = true
                            dirty = true
                        end
                        if !used && game.automap !== nothing && Automap.responder!(game.automap, key, true, game)
                            used = true
                            dirty = true
                        end
                        if used
                            pop!(held, key, nothing)
                        else
                            held[key] = true
                            game.finale !== nothing && game.gamestate == "finale" && Finale.responder!(game.finale)
                            game.cheatbox !== nothing && feed!(game.cheatbox, key, game)
                            if game.gamestate == "view" && !menu.active
                                if key == "equals" && game.screen_size < 8
                                    game.screen_size += 1
                                    dirty = true
                                elseif key == "minus" && game.screen_size > 0
                                    game.screen_size -= 1
                                    dirty = true
                                elseif key == "f11"
                                    game.show_fps = !game.show_fps
                                    dirty = true
                                end
                            end
                        end
                    else
                        pop!(held, key, nothing)
                        game.automap !== nothing && Automap.responder!(game.automap, key, false, game)
                    end
                end
            end
        end
        now = ticks()
        accum += now - last
        last = now
        guard = 0
        game.held = held
        while accum >= TICK_MS && guard < 4
            if game.wiping
                tick_wipe!(game.wipe, 1, fb) && (game.wiping = false)
                dirty = true
            else
                ticker(menu) && (dirty = true)
                if game.gamestate == "view" && game.player !== nothing && game.world !== nothing
                    game.automap !== nothing && Automap.ticker!(game.automap, game)
                    if !mouse_live[]
                        game.mousex = 0
                        game.mousey = 0
                        game.mouse_fire = false
                    end
                    if menu.active
                        game.player.cmd = empty_cmd()
                        game.mousex = 0
                        game.mousey = 0
                    else
                        cmd, heldn = build_ticcmd(held, game.turnheld, game.player, game.mousex, game.mousey, game.mouse_sensitivity, game.mouse_fire)
                        game.turnheld = heldn
                        game.player.cmd = cmd
                        game.mousex = 0
                        game.mousey = 0
                    end
                    think!(game.world, game.player, game, game.leveltime)
                    tick_fx!(game.world)
                    if game.player !== nothing && game.player.playerstate == Player.PST_REBORN
                        begin_level(game)
                    else
                        tick_actors!(game.world, game)
                        if game.specials !== nothing
                            tick!(game.specials)
                        end
                        if game.specials !== nothing && game.specials.exit_requested
                            begin_exit(game)
                            dirty = true
                            break
                        end
                        game.leveltime += 1
                        game.statusbar !== nothing && Status.ticker!(game.statusbar, game.player)
                    end
                    dirty = true
                elseif game.gamestate == "intermission" && game.wi !== nothing
                    Wi.ticker!(game.wi)
                    if game.wi !== nothing && game.wi.done
                        game.wi = nothing
                        advance_map(game)
                    end
                    dirty = true
                elseif game.gamestate == "finale" && game.finale !== nothing
                    Finale.ticker!(game.finale)
                    if game.finale !== nothing && game.finale.done
                        finish_finale(game)
                    end
                    dirty = true
                end
            end
            accum -= TICK_MS
            guard += 1
        end
        if accum > TICK_MS * 4
            accum = 0
        end
        dirty && (redraw(); dirty = false)
        update_sound!(sound)
        want_mouse = game.use_mouse && game.gamestate == "view" && !menu.active
        if mouse_relative(want_mouse) || !want_mouse
            mouse_live[] = false
            game.mousex = 0
            game.mousey = 0
            game.mouse_fire = false
        else
            mouse_live[] = true
        end
        opts.novsync || delay(1)
        fps_n += 1
        fps_now = ticks()
        if fps_now - fps_t >= 1000
            game.fps_text = "$(fps_n) FPS"
            fps_n = 0
            fps_t = fps_now
            game.show_fps && (dirty = true)
        end
    end
finally
    shutdown_sound!(sound)
    shutdown(screen)
    println("janela fechada")
end

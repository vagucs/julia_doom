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
# Janela, paleta e teclado. O ccall fala com a SDL2.dll.
# O quadro de 320x200 e a paleta ficam em Julia. Nada de renderer em C.

module Video

export init, shutdown, set_palette, present, poll, delay, ticks
export set_crt!, mouse_relative, toggle_fullscreen
export audio_open, audio_queue, audio_close
export music_open, music_status, music_play, music_volume, music_close

const SDL = raw"C:\msys64\ucrt64\bin\SDL2.dll"
const INIT_VIDEO = UInt32(0x00000020)
const WINDOWPOS_CENTERED = Cint(0x2fff0000)
const WINDOW_SHOWN = UInt32(0x00000004)
const RENDERER_ACCELERATED = UInt32(0x00000002)
const RENDERER_SOFTWARE = UInt32(0x00000001)
const PIXELFORMAT_ARGB8888 = UInt32(372645892)
const TEXTUREACCESS_STREAMING = Cint(1)
const QUIT = UInt32(0x100)
const KEYDOWN = UInt32(0x300)
const KEYUP = UInt32(0x301)
const MOUSEMOTION = UInt32(0x400)
const MOUSEDOWN = UInt32(0x401)
const MOUSEUP = UInt32(0x402)
const WINDOW_FULLSCREEN = UInt32(0x00000001)
const EVENT_SIZE = 56

mutable struct Screen
    window::Ptr{Cvoid}
    renderer::Ptr{Cvoid}
    texture::Ptr{Cvoid}
    w::Int
    h::Int
    palette::Vector{UInt32}
    pixels::Vector{UInt32}
    open::Bool
    win_w::Int
    win_h::Int
    crt::Bool
    crt_tex::Ptr{Cvoid}
    crt_map::Vector{Int}
    crt_gain::Vector{UInt8}
    crt_pix::Vector{UInt32}
    crt_src::Vector{UInt8}
    crt_blur::Vector{UInt8}
    crt_mask::Vector{Int}
end

sdl_error() = unsafe_string(ccall((:SDL_GetError, SDL), Ptr{UInt8}, ()))

function init(w::Integer, h::Integer, scale::Integer=2, title::AbstractString="DOOM"; novsync::Bool=false)
    (w < 1 || h < 1) && error("tamanho de textura invalido")
    scale < 1 && (scale = 1)
    isfile(SDL) || error("SDL2.dll nao encontrada: $SDL")
    ccall((:SDL_SetMainReady, SDL), Cvoid, ())
    ccall((:SDL_SetHint, SDL), Cint, (Cstring, Cstring), "SDL_RENDER_SCALE_QUALITY", "0")
    novsync && ccall((:SDL_SetHint, SDL), Cint, (Cstring, Cstring), "SDL_RENDER_VSYNC", "0")
    ccall((:SDL_Init, SDL), Cint, (UInt32,), INIT_VIDEO) == 0 || error("SDL_Init: $(sdl_error())")
    window = ccall((:SDL_CreateWindow, SDL), Ptr{Cvoid},
        (Cstring, Cint, Cint, Cint, Cint, UInt32),
        title, WINDOWPOS_CENTERED, WINDOWPOS_CENTERED, Cint(w * scale), Cint(h * scale), WINDOW_SHOWN)
    if window == C_NULL
        ccall((:SDL_Quit, SDL), Cvoid, ())
        error("SDL_CreateWindow: $(sdl_error())")
    end
    renderer = ccall((:SDL_CreateRenderer, SDL), Ptr{Cvoid},
        (Ptr{Cvoid}, Cint, UInt32), window, Cint(-1), RENDERER_ACCELERATED)
    if renderer == C_NULL
        renderer = ccall((:SDL_CreateRenderer, SDL), Ptr{Cvoid},
            (Ptr{Cvoid}, Cint, UInt32), window, Cint(-1), RENDERER_SOFTWARE)
    end
    if renderer == C_NULL
        ccall((:SDL_DestroyWindow, SDL), Cvoid, (Ptr{Cvoid},), window)
        ccall((:SDL_Quit, SDL), Cvoid, ())
        error("SDL_CreateRenderer: $(sdl_error())")
    end
    novsync && ccall((:SDL_RenderSetVSync, SDL), Cint, (Ptr{Cvoid}, Cint), renderer, Cint(0))
    texture = ccall((:SDL_CreateTexture, SDL), Ptr{Cvoid},
        (Ptr{Cvoid}, UInt32, Cint, Cint, Cint),
        renderer, PIXELFORMAT_ARGB8888, TEXTUREACCESS_STREAMING, Cint(w), Cint(h))
    if texture == C_NULL
        ccall((:SDL_DestroyRenderer, SDL), Cvoid, (Ptr{Cvoid},), renderer)
        ccall((:SDL_DestroyWindow, SDL), Cvoid, (Ptr{Cvoid},), window)
        ccall((:SDL_Quit, SDL), Cvoid, ())
        error("SDL_CreateTexture: $(sdl_error())")
    end
    palette = Vector{UInt32}(undef, 256)
    for i in 0:255
        c = UInt32(i)
        palette[i + 1] = 0xff000000 | (c << 16) | (c << 8) | c
    end
    Screen(window, renderer, texture, Int(w), Int(h), palette, Vector{UInt32}(undef, Int(w) * Int(h)), true,
        Int(w * scale), Int(h * scale), false, C_NULL, Int[], UInt8[], UInt32[], UInt8[], UInt8[], Int[])
end

function shutdown(screen::Screen)
    screen.open || return
    screen.crt_tex != C_NULL && ccall((:SDL_DestroyTexture, SDL), Cvoid, (Ptr{Cvoid},), screen.crt_tex)
    screen.texture != C_NULL && ccall((:SDL_DestroyTexture, SDL), Cvoid, (Ptr{Cvoid},), screen.texture)
    screen.renderer != C_NULL && ccall((:SDL_DestroyRenderer, SDL), Cvoid, (Ptr{Cvoid},), screen.renderer)
    screen.window != C_NULL && ccall((:SDL_DestroyWindow, SDL), Cvoid, (Ptr{Cvoid},), screen.window)
    ccall((:SDL_Quit, SDL), Cvoid, ())
    screen.crt_tex = C_NULL
    screen.texture = C_NULL
    screen.renderer = C_NULL
    screen.window = C_NULL
    screen.open = false
    nothing
end

function set_palette(screen::Screen, rgb::Vector{UInt8})
    length(rgb) >= 768 || error("paleta precisa de 768 bytes RGB")
    pal = screen.palette
    @inbounds for i in 0:255
        r = UInt32(rgb[i * 3 + 1])
        g = UInt32(rgb[i * 3 + 2])
        b = UInt32(rgb[i * 3 + 3])
        pal[i + 1] = 0xff000000 | (r << 16) | (g << 8) | b
    end
    nothing
end

function set_crt!(screen::Screen, on::Bool)
    screen.crt = on
    nothing
end

function mouse_relative(on::Bool)
    ccall((:SDL_SetRelativeMouseMode, SDL), Cint, (Cint,), on ? Cint(1) : Cint(0))
    nothing
end

fullscreen_on = false

function toggle_fullscreen(screen::Screen)
    global fullscreen_on
    next_on = !fullscreen_on
    if ccall((:SDL_SetWindowFullscreen, SDL), Cint, (Ptr{Cvoid}, UInt32),
            screen.window, next_on ? WINDOW_FULLSCREEN : UInt32(0)) == 0
        fullscreen_on = next_on
    end
    fullscreen_on
end

function crt_build!(screen)
    dw, dh = screen.win_w, screen.win_h
    (dw < 2 || dh < 2) && return false
    if length(screen.crt_map) == dw * dh && screen.crt_tex != C_NULL
        return true
    end
    screen.crt_tex != C_NULL && ccall((:SDL_DestroyTexture, SDL), Cvoid, (Ptr{Cvoid},), screen.crt_tex)
    screen.crt_tex = ccall((:SDL_CreateTexture, SDL), Ptr{Cvoid},
        (Ptr{Cvoid}, UInt32, Cint, Cint, Cint),
        screen.renderer, PIXELFORMAT_ARGB8888, TEXTUREACCESS_STREAMING, Cint(dw), Cint(dh))
    screen.crt_tex == C_NULL && return false
    screen.crt_map = Vector{Int}(undef, dw * dh)
    screen.crt_gain = Vector{UInt8}(undef, dw * dh)
    screen.crt_pix = Vector{UInt32}(undef, dw * dh)
    isempty(screen.crt_src) && (screen.crt_src = Vector{UInt8}(undef, 320 * 200 * 3))
    isempty(screen.crt_blur) && (screen.crt_blur = Vector{UInt8}(undef, 320 * 200 * 3))
    sl = dh / 200 - 1
    sl < 0 && (sl = 0.0)
    sl > 1 && (sl = 1.0)
    sl *= 0.45
    for y in 0:dh - 1
        ny = 2 * y / dh - 1
        ny2 = ny * ny
        for x in 0:dw - 1
            nx = 2 * (x + 0.5) / dw - 1
            u = nx * (1 + ny2 / 32)
            v = ny * (1 + (nx * nx) / 24)
            outside = u <= -1 || u >= 1 || v <= -1 || v >= 1
            sx = (u + 1) * 0.5 * 320
            sy = (v + 1) * 0.5 * 200
            ix = sx < 0 ? ceil(Int, sx) : floor(Int, sx)
            iy = sy < 0 ? ceil(Int, sy) : floor(Int, sy)
            ix = clamp(ix, 0, 319)
            iy = clamp(iy, 0, 199)
            d = (sy - iy) - 0.5
            uu = (u + 1) * 0.5
            vv = (v + 1) * 0.5
            vig = 16 * uu * vv * (1 - uu) * (1 - vv)
            vig < 0 && (vig = 0.0)
            base = vig < 1e-20 ? 1e-20 : vig
            g = (1 - sl * 4 * d * d) * (base^0.12) * 255
            g = clamp(g, 0, 255)
            i = y * dw + x + 1
            if outside
                screen.crt_map[i] = 65535
                screen.crt_gain[i] = 0x00
            else
                screen.crt_map[i] = iy * 320 + ix
                screen.crt_gain[i] = UInt8(floor(Int, g + 0.5))
            end
        end
    end
    off, boost = dw >= 640 ? (0.70, 1.40) : (1.0, 1.15)
    screen.crt_mask = Int[]
    for m in 0:2
        for c in 0:2
            mv = 256 * boost
            m != c && (mv *= off)
            push!(screen.crt_mask, floor(Int, mv))
        end
    end
    true
end

function crt_show(screen::Screen, fb::Vector{UInt8})
    (screen.renderer == C_NULL || screen.win_w < 2 || screen.win_h < 2) && return false
    crt_build!(screen) || return false
    pal = screen.palette
    src, blur = screen.crt_src, screen.crt_blur
    for i in 0:320 * 200 - 1
        c = pal[fb[i + 1] + 1]
        src[i * 3 + 1] = UInt8((c >> 16) & 0xff)
        src[i * 3 + 2] = UInt8((c >> 8) & 0xff)
        src[i * 3 + 3] = UInt8(c & 0xff)
    end
    for y in 0:199
        for x in 0:319
            at = (y * 320 + x) * 3
            left = x > 0 ? at - 3 : at
            right = x < 319 ? at + 3 : at
            for k in 1:3
                blur[at + k] = UInt8(fld(Int(src[left + k]) + Int(src[at + k]) * 2 + Int(src[right + k]), 4))
            end
        end
    end
    dw, dh = screen.win_w, screen.win_h
    pix = screen.crt_pix
    for y in 0:dh - 1
        for x in 0:dw - 1
            i = y * dw + x
            idx = screen.crt_map[i + 1]
            if idx == 65535
                pix[i + 1] = 0xff000000
            else
                gain = Int(screen.crt_gain[i + 1])
                mask = (x % 3) * 3
                base = idx * 3
                r = fld(Int(blur[base + 1]) * gain * screen.crt_mask[mask + 1], 65536)
                g = fld(Int(blur[base + 2]) * gain * screen.crt_mask[mask + 2], 65536)
                b = fld(Int(blur[base + 3]) * gain * screen.crt_mask[mask + 3], 65536)
                r > 255 && (r = 255)
                g > 255 && (g = 255)
                b > 255 && (b = 255)
                pix[i + 1] = 0xff000000 | (UInt32(r) << 16) | (UInt32(g) << 8) | UInt32(b)
            end
        end
    end
    GC.@preserve pix ccall((:SDL_UpdateTexture, SDL), Cint,
        (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{UInt32}, Cint),
        screen.crt_tex, C_NULL, pointer(pix), Cint(dw * 4))
    ccall((:SDL_RenderClear, SDL), Cint, (Ptr{Cvoid},), screen.renderer)
    ccall((:SDL_RenderCopy, SDL), Cint,
        (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}),
        screen.renderer, screen.crt_tex, C_NULL, C_NULL)
    ccall((:SDL_RenderPresent, SDL), Cvoid, (Ptr{Cvoid},), screen.renderer)
    true
end

function present(screen::Screen, fb::Vector{UInt8})
    screen.open || error("SDL ainda nao foi iniciado")
    n = screen.w * screen.h
    length(fb) >= n || error("framebuffer curto")
    if screen.crt && screen.w == 320 && screen.h == 200 && crt_show(screen, fb)
        return
    end
    pix = screen.pixels
    pal = screen.palette
    @inbounds for i in 1:n
        pix[i] = pal[fb[i] + 1]
    end
    GC.@preserve pix ccall((:SDL_UpdateTexture, SDL), Cint,
        (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{UInt32}, Cint),
        screen.texture, C_NULL, pointer(pix), Cint(screen.w * 4))
    ccall((:SDL_RenderClear, SDL), Cint, (Ptr{Cvoid},), screen.renderer)
    ccall((:SDL_RenderCopy, SDL), Cint,
        (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}),
        screen.renderer, screen.texture, C_NULL, C_NULL)
    ccall((:SDL_RenderPresent, SDL), Cvoid, (Ptr{Cvoid},), screen.renderer)
    nothing
end

function u32_at(buf::Vector{UInt8}, at::Int)
    i = at + 1
    UInt32(buf[i]) | (UInt32(buf[i + 1]) << 8) | (UInt32(buf[i + 2]) << 16) | (UInt32(buf[i + 3]) << 24)
end

function i32_at(buf::Vector{UInt8}, at::Int)
    reinterpret(Int32, u32_at(buf, at))
end

function poll(screen::Screen)
    events = NamedTuple{(:quit, :down, :sym, :mouse, :dx, :dy, :button, :alt), Tuple{Bool, Bool, Int32, Bool, Int, Int, Int, Bool}}[]
    screen.open || return events
    ev = Vector{UInt8}(undef, EVENT_SIZE)
    while true
        n = GC.@preserve ev ccall((:SDL_PollEvent, SDL), Cint, (Ptr{Cvoid},), pointer(ev))
        n == 0 && break
        typ = u32_at(ev, 0)
        if typ == QUIT
            push!(events, (quit=true, down=true, sym=Int32(0), mouse=false, dx=0, dy=0, button=0, alt=false))
        elseif typ == KEYDOWN || typ == KEYUP
            (typ == KEYDOWN && ev[14] != 0) && continue
            modv = Int(u32_at(ev, 24) & 0xffff)
            alt = (fld(modv, 256) % 4) != 0
            push!(events, (quit=false, down=typ == KEYDOWN, sym=i32_at(ev, 20), mouse=false, dx=0, dy=0, button=0, alt=alt))
        elseif typ == MOUSEMOTION
            push!(events, (quit=false, down=false, sym=Int32(-1), mouse=true, dx=Int(i32_at(ev, 28)), dy=Int(i32_at(ev, 32)), button=0, alt=false))
        elseif (typ == MOUSEDOWN || typ == MOUSEUP) && ev[17] == 1
            push!(events, (quit=false, down=typ == MOUSEDOWN, sym=Int32(-1), mouse=true, dx=0, dy=0, button=1, alt=false))
        end
    end
    events
end

delay(ms::Integer) = ccall((:SDL_Delay, SDL), Cvoid, (UInt32,), UInt32(ms))

ticks() = Int(ccall((:SDL_GetTicks, SDL), UInt32, ()))

const INIT_AUDIO = UInt32(0x00000010)
const AUDIO_S16 = UInt16(0x8010)
const ALLOW_RATE = Cint(1)
const ALLOW_CH = Cint(4)
const WINMM = "winmm"

mutable struct AudioSpec
    freq::Int32
    format::UInt16
    channels::UInt8
    silence::UInt8
    samples::UInt16
    padding::UInt16
    size::UInt32
    callback::Ptr{Cvoid}
    userdata::Ptr{Cvoid}
end

audio_dev = UInt32(0)

function audio_open()
    global audio_dev
    if audio_dev != 0
        ccall((:SDL_CloseAudioDevice, SDL), Cvoid, (UInt32,), audio_dev)
        audio_dev = UInt32(0)
    end
    ccall((:SDL_InitSubSystem, SDL), Cint, (UInt32,), INIT_AUDIO) == 0 || return nothing
    want = AudioSpec(11025, AUDIO_S16, 1, 0, 512, 0, 0, C_NULL, C_NULL)
    have = AudioSpec(0, 0, 0, 0, 0, 0, 0, C_NULL, C_NULL)
    audio_dev = ccall((:SDL_OpenAudioDevice, SDL), UInt32,
        (Ptr{Cvoid}, Cint, Ref{AudioSpec}, Ref{AudioSpec}, Cint),
        C_NULL, 0, want, have, ALLOW_RATE + ALLOW_CH)
    if audio_dev == 0 || have.format != AUDIO_S16
        if audio_dev != 0
            ccall((:SDL_CloseAudioDevice, SDL), Cvoid, (UInt32,), audio_dev)
            audio_dev = UInt32(0)
        end
        return nothing
    end
    ccall((:SDL_PauseAudioDevice, SDL), Cvoid, (UInt32, Cint), audio_dev, 0)
    Int(have.freq), Int(have.channels)
end

function audio_queue(pcm::Vector{UInt8})
    global audio_dev
    (audio_dev == 0 || isempty(pcm)) && return
    queued = ccall((:SDL_GetQueuedAudioSize, SDL), UInt32, (UInt32,), audio_dev)
    queued > 11025 * 4 && return
    GC.@preserve pcm ccall((:SDL_QueueAudio, SDL), Cint,
        (UInt32, Ptr{Cvoid}, UInt32), audio_dev, pointer(pcm), UInt32(length(pcm)))
    nothing
end

function audio_close()
    global audio_dev
    if audio_dev != 0
        ccall((:SDL_CloseAudioDevice, SDL), Cvoid, (UInt32,), audio_dev)
        audio_dev = UInt32(0)
    end
    nothing
end

function mci(cmd::AbstractString, ret::Union{Nothing,Vector{UInt16}}=nothing)
    if ret === nothing
        return ccall((:mciSendStringW, WINMM), UInt32,
            (Cwstring, Ptr{UInt16}, UInt32, Ptr{Cvoid}), cmd, C_NULL, 0, C_NULL)
    end
    ccall((:mciSendStringW, WINMM), UInt32,
        (Cwstring, Ptr{UInt16}, UInt32, Ptr{Cvoid}), cmd, ret, UInt32(length(ret)), C_NULL)
end

function music_close()
    mci("close doommus")
    nothing
end

function music_open(path::AbstractString)
    music_close()
    quoted = replace(path, "/" => "\\")
    if mci("open \"$quoted\" type sequencer alias doommus") != 0
        mci("open \"$quoted\" alias doommus") != 0 && return false
    end
    mci("play doommus from 0") == 0
end

function music_status()
    buf = zeros(UInt16, 64)
    mci("status doommus mode", buf) != 0 && return ""
    n = findfirst(iszero, buf)
    n === nothing && return ""
    n == 1 && return ""
    String(transcode(UInt8, buf[1:n - 1]))
end

music_play() = mci("play doommus from 0") == 0

music_volume(level::Integer) = mci("setaudio doommus volume to $level")

end

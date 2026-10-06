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
# Efeitos DS* e musica D_*. A mistura fica aqui. A SDL enfileira o PCM e o MCI abre o MIDI.

module Snd

using ..Wad
using ..Mus2Mid
using ..Video

export Sound, new_sound, play, decode
export init_sound!, update_sound!, shutdown_sound!, change_music!, has_music, play_title_music!, play_level_music!
export DOOM2_MUSIC
export set_sfx_volume!, set_music_volume!, stop_music!

const MAX_VOICES = 8
const DOOM2_MUSIC = (
    "runnin", "stalks", "countd", "betwee", "doom", "the_da",
    "shawn", "ddtblu", "in_cit", "dead", "stlks2", "theda2",
    "doom2", "ddtbl2", "runni2", "dead2", "stlks3", "romero",
    "shawn2", "messag", "count2", "ddtbl3", "ampie", "theda3",
    "adrian", "messg2", "romer2", "tense", "shawn3", "openin",
    "evil", "ultima",
)

music_seq = 0

mutable struct Voice
    samples::Vector{Int}
    pos::Int
    n::Int
    vol::Int
end

mutable struct Sound
    sfx_volume::Int
    music_volume::Int
    wad::Any
    cache::Dict{String,Any}
    enabled::Bool
    music_enabled::Bool
    ready::Bool
    freq::Int
    channels::Int
    music_path::String
    music_name::String
    music_loop::Bool
    music_on::Bool
    voices::Vector{Voice}
    last_ms::Int
end

function new_sound()
    Sound(8, 8, nothing, Dict{String,Any}(), true, true, false, 11025, 1, "", "", false, false, Voice[], 0)
end

function decode(data::AbstractVector{UInt8}, mix_rate, mix_ch)
    if length(data) < 8 || data[1] != 3 || data[2] != 0
        return nothing
    end
    rate = Int(data[3]) + Int(data[4]) * 256
    length_n = Int(data[5]) + Int(data[6]) * 256 + Int(data[7]) * 65536 + Int(data[8]) * 16777216
    (length_n > length(data) - 8 || length_n <= 48 || rate <= 0) && return nothing
    length_n -= 32
    length_n <= 0 && return nothing
    out_n = length_n
    if mix_rate != rate
        out_n = max(1, fld(length_n * mix_rate, rate))
    end
    samples = Vector{Int}(undef, out_n)
    for i in 0:out_n - 1
        src_i = i
        if mix_rate != rate
            src_i = min(length_n - 1, fld(i * length_n, out_n))
        end
        samples[i + 1] = (Int(data[17 + src_i]) - 128) * 256
    end
    if mix_ch >= 2
        stereo = Vector{Int}(undef, out_n * 2)
        for i in 1:out_n
            stereo[2 * i - 1] = samples[i]
            stereo[2 * i] = samples[i]
        end
        samples = stereo
    end
    samples
end

function init_sound!(self::Sound, wadfile)
    self.wad = wadfile
    opened = audio_open()
    if opened !== nothing
        self.freq, self.channels = opened
        self.ready = true
        self.enabled = true
    else
        self.ready = false
        self.enabled = false
    end
    self.last_ms = ticks()
    set_music_volume!(self, self.music_volume)
    nothing
end

function play(self::Sound, name::AbstractString)
    (!self.enabled || !self.ready || self.wad === nothing || name == "") && return
    key = lowercase(name)
    samples = get(self.cache, key, nothing)
    if samples === nothing
        lump = "DS" * uppercase(first(key, 6))
        n = check_num_for_name(self.wad, lump)
        if n < 0
            self.cache[key] = false
            return
        end
        samples = decode(cache_lump_num(self.wad, n), self.freq, 1)
        if samples === nothing
            self.cache[key] = false
            return
        end
        self.cache[key] = samples
    end
    samples == false && return
    if length(self.voices) >= MAX_VOICES
        popfirst!(self.voices)
    end
    push!(self.voices, Voice(samples, 0, length(samples), self.sfx_volume))
    nothing
end

function set_sfx_volume!(self::Sound, vol)
    self.sfx_volume = clamp(vol, 0, 15)
    nothing
end

function set_music_volume!(self::Sound, vol)
    self.music_volume = clamp(vol, 0, 15)
    self.music_on && music_volume(fld(self.music_volume * 1000, 15))
    nothing
end

function stop_music!(self::Sound)
    if self.music_on
        music_close()
    end
    self.music_on = false
    self.music_name = ""
    self.music_loop = false
    if self.music_path != ""
        isfile(self.music_path) && rm(self.music_path)
        self.music_path = ""
    end
    nothing
end

function has_music(self::Sound, name::AbstractString)
    self.wad !== nothing && check_num_for_name(self.wad, "D_" * uppercase(first(name, 6))) >= 0
end

function change_music!(self::Sound, name::AbstractString, looping=true)
    (!self.music_enabled || self.wad === nothing || name == "") && return
    lowercase(name) == self.music_name && return
    lump = "D_" * uppercase(first(name, 6))
    n = check_num_for_name(self.wad, lump)
    n < 0 && return
    midi = mus2mid(cache_lump_num(self.wad, n))
    (midi === nothing || isempty(midi)) && return
    stop_music!(self)
    global music_seq
    music_seq += 1
    dir = get(ENV, "TEMP", ".")
    path = joinpath(dir, "doommus_$(time_ns())_$(music_seq).mid")
    write(path, midi)
    self.music_path = path
    self.music_name = lowercase(name)
    self.music_loop = looping
    if music_open(path)
        self.music_on = true
        set_music_volume!(self, self.music_volume)
        println("musica $(self.music_name)")
        return
    end
    println("musica muda")
    stop_music!(self)
    nothing
end

function play_title_music!(self::Sound)
    self.wad === nothing && return
    if check_num_for_name(self.wad, "MAP01") >= 0
        change_music!(self, "dm2ttl", false)
    elseif check_num_for_name(self.wad, "D_INTROA") >= 0
        change_music!(self, "introa", false)
    else
        change_music!(self, "intro", false)
    end
end

function play_level_music!(self::Sound, episode, mapn)
    self.wad === nothing && return
    name = if check_num_for_name(self.wad, "MAP01") >= 0
        DOOM2_MUSIC[mod(max(1, mapn) - 1, length(DOOM2_MUSIC)) + 1]
    else
        "e$(episode)m$(mapn)"
    end
    change_music!(self, name, true)
end

function push_s16!(bytes, n)
    n > 32767 && (n = 32767)
    n < -32768 && (n = -32768)
    n < 0 && (n += 65536)
    push!(bytes, UInt8(n % 256), UInt8(fld(n, 256) % 256))
    nothing
end

function update_sound!(self::Sound)
    if self.ready
        now = ticks()
        dt = now - self.last_ms
        self.last_ms = now
        dt < 0 && (dt = 0)
        dt > 1000 && (dt = 1000)
        count = fld(dt * self.freq, 1000)
        if count > 0 && !isempty(self.voices)
            frame = self.channels >= 2 ? 2 : 1
            bytes = UInt8[]
            for _ in 1:count
                acc = 0
                for v in self.voices
                    if v.pos < v.n
                        v.pos += 1
                        acc += v.samples[v.pos] * v.vol
                    end
                end
                acc = fld(acc, 15)
                push_s16!(bytes, acc)
                frame == 2 && push_s16!(bytes, acc)
            end
            filter!(v -> v.pos < v.n, self.voices)
            isempty(bytes) || audio_queue(bytes)
        end
    end
    if self.music_on && self.music_loop
        mode = lowercase(music_status())
        if mode != "" && mode != "playing"
            music_play()
        end
    end
    nothing
end

function shutdown_sound!(self::Sound)
    stop_music!(self)
    empty!(self.voices)
    self.ready = false
    audio_close()
    nothing
end

end

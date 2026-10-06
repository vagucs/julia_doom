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
# MUS para MIDI. O mesmo resultado de mus2mid.py.

module Mus2Mid

using ..Compat

export mus2mid

const MUS_RELEASEKEY = 0x00
const MUS_PRESSKEY = 0x10
const MUS_PITCHWHEEL = 0x20
const MUS_SYSTEMEVENT = 0x30
const MUS_CHANGECONTROLLER = 0x40
const MUS_SCOREEND = 0x60
const HEADER = UInt8[
    0x4d, 0x54, 0x68, 0x64, 0x00, 0x00, 0x00, 0x06,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x46, 0x4d, 0x54,
    0x72, 0x6b, 0x00, 0x00, 0x00, 0x00,
]
const CONTROLLER_MAP = UInt8[
    0x00, 0x20, 0x01, 0x07, 0x0a, 0x0b, 0x5b, 0x5d,
    0x40, 0x43, 0x78, 0x7b, 0x7e, 0x7f, 0x79,
]

mutable struct MidiOut
    body::Vector{UInt8}
    queued::Int
    tracksize::Int
    velocities::Vector{Int}
    channel_map::Vector{Int}
end

function write_time!(out, time)
    groups = Int[time % 128]
    t = fld(time, 128)
    while t != 0
        pushfirst!(groups, (t % 128) + 128)
        t = fld(t, 128)
    end
    for g in groups
        push!(out.body, UInt8(g))
        out.tracksize += 1
    end
    out.queued = 0
    nothing
end

function write!(out, data)
    write_time!(out, out.queued)
    append!(out.body, data)
    out.tracksize += length(data)
    nothing
end

function allocate_channel(out)
    result = out.channel_map[1]
    for i in 2:16
        out.channel_map[i] > result && (result = out.channel_map[i])
    end
    result += 1
    result == 9 && (result += 1)
    result
end

function midi_channel(out, mus_channel)
    mus_channel == 15 && return 9
    if out.channel_map[mus_channel + 1] == -1
        out.channel_map[mus_channel + 1] = allocate_channel(out)
        ch = out.channel_map[mus_channel + 1]
        write!(out, UInt8[UInt8(bor(0xb0, ch)), 0x7b, 0])
    end
    out.channel_map[mus_channel + 1]
end

function new_midi()
    MidiOut(UInt8[], 0, 0, fill(127, 16), fill(-1, 16))
end

function mus2mid(mus::AbstractVector{UInt8})
    if length(mus) >= 4 && mus[1] == UInt8('M') && mus[2] == UInt8('T') && mus[3] == UInt8('h') && mus[4] == UInt8('d')
        return Vector{UInt8}(mus)
    end
    if length(mus) < 16 || mus[1] != UInt8('M') || mus[2] != UInt8('U') || mus[3] != UInt8('S') || mus[4] != 0x1a
        return nothing
    end
    scorestart = Int(mus[7]) + Int(mus[8]) * 256
    pos = scorestart
    out = new_midi()
    hitscoreend = false
    function read_u8()
        pos >= length(mus) && return nothing
        b = Int(mus[pos + 1])
        pos += 1
        b
    end
    while !hitscoreend
        while !hitscoreend
            descriptor = read_u8()
            descriptor === nothing && return nothing
            channel = midi_channel(out, Int(band(descriptor, 0x0f)))
            event = Int(band(descriptor, 0x70))
            if event == MUS_RELEASEKEY
                key = read_u8()
                key === nothing && return nothing
                write!(out, UInt8[UInt8(bor(0x80, channel)), UInt8(band(key, 0x7f)), 0])
            elseif event == MUS_PRESSKEY
                key = read_u8()
                key === nothing && return nothing
                if band(key, 0x80) != 0
                    vel = read_u8()
                    vel === nothing && return nothing
                    out.velocities[channel + 1] = Int(band(vel, 0x7f))
                end
                write!(out, UInt8[UInt8(bor(0x90, channel)), UInt8(band(key, 0x7f)), UInt8(out.velocities[channel + 1])])
            elseif event == MUS_PITCHWHEEL
                key = read_u8()
                key === nothing && break
                wheel = key * 64
                write!(out, UInt8[UInt8(bor(0xe0, channel)), UInt8(wheel % 128), UInt8(fld(wheel, 128) % 128)])
            elseif event == MUS_SYSTEMEVENT
                ctrl = read_u8()
                (ctrl === nothing || ctrl < 10 || ctrl > 14) && return nothing
                write!(out, UInt8[UInt8(bor(0xb0, channel)), CONTROLLER_MAP[ctrl + 1], 0])
            elseif event == MUS_CHANGECONTROLLER
                ctrl = read_u8()
                val = read_u8()
                (ctrl === nothing || val === nothing) && return nothing
                if ctrl == 0
                    write!(out, UInt8[UInt8(bor(0xc0, channel)), UInt8(band(val, 0x7f))])
                else
                    (ctrl < 1 || ctrl > 9) && return nothing
                    working = band(val, 0x80) != 0 ? 0x7f : val
                    write!(out, UInt8[UInt8(bor(0xb0, channel)), CONTROLLER_MAP[ctrl + 1], UInt8(working)])
                end
            elseif event == MUS_SCOREEND
                hitscoreend = true
            else
                return nothing
            end
            band(descriptor, 0x80) != 0 && break
        end
        if !hitscoreend
            timedelay = 0
            while true
                working = read_u8()
                working === nothing && return nothing
                timedelay = timedelay * 128 + Int(band(working, 0x7f))
                band(working, 0x80) == 0 && break
            end
            out.queued += timedelay
        end
    end
    write_time!(out, out.queued)
    push!(out.body, 0xff, 0x2f, 0x00)
    out.tracksize += 3
    header = copy(HEADER)
    ts = out.tracksize
    header[19] = UInt8(fld(ts, 16777216) % 256)
    header[20] = UInt8(fld(ts, 65536) % 256)
    header[21] = UInt8(fld(ts, 256) % 256)
    header[22] = UInt8(ts % 256)
    append!(header, out.body)
    header
end

end

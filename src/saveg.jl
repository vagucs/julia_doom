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
# Save de 6 vagas. Cabecalho de 24 bytes, magica DOOMPY01 e JSON.

module Saveg

using ..Collision
using ..Compat

export encode, decode, path, description, write_save, read_save, apply_save!, load_save

const SAVESTRINGSIZE = 24
const MAGIC = "DOOMPY01"
const EMPTY = "empty slot"

function enc_str(s)
    out = IOBuffer()
    print(out, '"')
    for c in s
        o = Int(c)
        if c == '"'
            print(out, "\\\"")
        elseif c == '\\'
            print(out, "\\\\")
        elseif c == '\n'
            print(out, "\\n")
        elseif c == '\r'
            print(out, "\\r")
        elseif c == '\t'
            print(out, "\\t")
        elseif o < 32
            print(out, "\\u", lpad(string(o, base=16), 4, '0'))
        else
            print(out, c)
        end
    end
    print(out, '"')
    String(take!(out))
end

is_obj(v) = v isa AbstractVector && !isempty(v) && first(v) isa Pair

function enc(v)
    v === nothing && return "null"
    v isa Bool && return v ? "true" : "false"
    if v isa Integer
        n = Int64(v)
        return string(n)
    end
    if v isa AbstractFloat
        (!isfinite(v)) && return "null"
        v == trunc(v) && abs(v) < 9007199254740992 && return string(trunc(Int64, v))
        return string(v)
    end
    v isa AbstractString && return enc_str(String(v))
    if v isa AbstractVector
        if is_obj(v)
            return "{" * join((enc_str(string(k)) * ":" * enc(val) for (k, val) in v), ",") * "}"
        end
        return "[" * join((enc(x) for x in v), ",") * "]"
    end
    "null"
end

encode(pairs) = enc(pairs)

function skip(s, i)
    n = ncodeunits(s)
    while i <= n
        c = s[i]
        (c != ' ' && c != '\n' && c != '\r' && c != '\t') && return i
        i = nextind(s, i)
    end
    i
end

function parse_at(s, i)
    i = skip(s, i)
    i > ncodeunits(s) && return nothing, i
    c = s[i]
    if c == '{'
        obj = Dict{String,Any}()
        i = nextind(s, i)
        i = skip(s, i)
        if i <= ncodeunits(s) && s[i] == '}'
            return obj, nextind(s, i)
        end
        while true
            key, i = parse_at(s, i)
            i = skip(s, i)
            i = nextind(s, i)
            val, i = parse_at(s, i)
            key isa AbstractString && (obj[String(key)] = val)
            i = skip(s, i)
            i > ncodeunits(s) && return obj, i
            c = s[i]
            c == '}' && return obj, nextind(s, i)
            i = nextind(s, i)
        end
    end
    if c == '['
        list = Any[]
        i = nextind(s, i)
        i = skip(s, i)
        if i <= ncodeunits(s) && s[i] == ']'
            return list, nextind(s, i)
        end
        while true
            val, i = parse_at(s, i)
            push!(list, val)
            i = skip(s, i)
            i > ncodeunits(s) && return list, i
            c = s[i]
            c == ']' && return list, nextind(s, i)
            i = nextind(s, i)
        end
    end
    if c == '"'
        i = nextind(s, i)
        chars = Char[]
        while i <= ncodeunits(s)
            ch = s[i]
            if ch == '"'
                return String(chars), nextind(s, i)
            end
            if ch == '\\'
                e = s[nextind(s, i)]
                if e == 'n'
                    push!(chars, '\n')
                elseif e == 'r'
                    push!(chars, '\r')
                elseif e == 't'
                    push!(chars, '\t')
                elseif e == 'u'
                    hex = s[i + 2:i + 5]
                    push!(chars, Char(parse(Int, hex, base=16)))
                    i += 4
                else
                    push!(chars, e)
                end
                i = nextind(s, nextind(s, i))
            else
                push!(chars, ch)
                i = nextind(s, i)
            end
        end
        return String(chars), i
    end
    if i + 3 <= ncodeunits(s) && s[i:i + 3] == "true"
        return true, i + 4
    end
    if i + 4 <= ncodeunits(s) && s[i:i + 4] == "false"
        return false, i + 5
    end
    if i + 3 <= ncodeunits(s) && s[i:i + 3] == "null"
        return nothing, i + 4
    end
    rest = s[i:end]
    m = match(r"^-?\d+\.?\d*([eE][+\-]?\d*)?", rest)
    (m === nothing || m.match == "" || m.match == "-") && return nothing, nextind(s, i)
    num = m.match
    value = occursin(r"[.eE]", num) ? parse(Float64, num) : parse(Int, num)
    value, i + ncodeunits(num)
end

decode(text) = parse_at(String(text), 1)[1]

function save_dir(game)
    path = getf(game, :iwad_path, "")
    m = match(r"^(.*)[/\\][^/\\]+$", path)
    (m === nothing || m.captures[1] == "") && return "."
    m.captures[1]
end

function path(game, slot)
    dir = save_dir(game)
    sep = "\\"
    occursin("/", dir) && !occursin("\\", dir) && (sep = "/")
    if dir == "."
        sep = ""
        dir = ""
    end
    dir * sep * "doomsav$(slot).dsg"
end

function pad_desc(text)
    text = string(text === nothing ? "" : text)
    ncodeunits(text) > SAVESTRINGSIZE && (text = text[1:SAVESTRINGSIZE])
    text * "\0"^(SAVESTRINGSIZE - ncodeunits(text))
end

function decode_desc(raw)
    cut = findfirst('\0', raw)
    cut !== nothing && (raw = raw[1:prevind(raw, cut)])
    replace(raw, r"\s+$" => "")
end

function description(game, slot)
    p = path(game, slot)
    isfile(p) || return EMPTY, false
    data = read(p)
    need = SAVESTRINGSIZE + ncodeunits(MAGIC)
    length(data) < need && return EMPTY, false
    header = String(data[1:need])
    header[SAVESTRINGSIZE + 1:need] != MAGIC && return EMPTY, false
    desc = decode_desc(header[1:SAVESTRINGSIZE])
    desc == "" && (desc = EMPTY)
    desc, true
end

getf(obj, name, default) = (obj !== nothing && hasproperty(obj, name)) ? getproperty(obj, name) : default

function num_list(src, n)
    out = Int[]
    for i in 1:n
        push!(out, i <= length(src) ? Int(src[i]) : 0)
    end
    out
end

function bool_list(src, n)
    out = Bool[]
    for i in 1:n
        push!(out, i <= length(src) && src[i] == true)
    end
    out
end

function mobj_index(mobjs, mo)
    mo === nothing && return nothing
    for (i, item) in enumerate(mobjs)
        item === mo && return i - 1
    end
    nothing
end

function dump_mobj(mo, mobjs)
    [
        "x" => Int(getf(mo, :x, 0)),
        "y" => Int(getf(mo, :y, 0)),
        "z" => Int(getf(mo, :z, 0)),
        "angle" => Int(getf(mo, :angle, 0)),
        "momx" => Int(getf(mo, :momx, 0)),
        "momy" => Int(getf(mo, :momy, 0)),
        "momz" => Int(getf(mo, :momz, 0)),
        "radius" => Int(getf(mo, :radius, 0)),
        "height" => Int(getf(mo, :height, 0)),
        "floorz" => Int(getf(mo, :floorz, 0)),
        "ceilingz" => Int(getf(mo, :ceilingz, 0)),
        "flags" => Int(getf(mo, :flags, 0)),
        "health" => Int(getf(mo, :health, 0)),
        "type" => Int(getf(mo, :type, 0)),
        "sprite" => string(getf(mo, :sprite, "")),
        "info" => nothing,
        "alive" => getf(mo, :alive, true) != false,
        "reactiontime" => Int(getf(mo, :reactiontime, 0)),
        "target" => mobj_index(mobjs, getf(mo, :target, nothing)),
        "movedir" => Int(getf(mo, :movedir, 0)),
        "movecount" => Int(getf(mo, :movecount, 0)),
        "ai_state" => "",
        "istate" => Int(getf(mo, :istate, 0)),
        "frame" => Int(getf(mo, :frame, 0)),
        "tics" => Int(getf(mo, :tics, 0)),
        "chase_tics" => Int(getf(mo, :chase_tics, 0)),
        "just_attacked" => getf(mo, :just_attacked, false) == true,
        "damage" => Int(getf(mo, :damage, 0)),
        "attack_kind" => string(getf(mo, :attack_kind, "")),
        "did_fire" => getf(mo, :did_fire, false) == true,
        "is_player" => getf(mo, :player, nothing) !== nothing,
    ]
end

function dump_player(p)
    [
        "playerstate" => Int(getf(p, :playerstate, 0)),
        "viewz" => Int(getf(p, :viewz, 0)),
        "viewheight" => Int(getf(p, :viewheight, 0)),
        "deltaviewheight" => Int(getf(p, :deltaviewheight, 0)),
        "bob" => Int(getf(p, :bob, 0)),
        "health" => Int(getf(p, :health, 0)),
        "armorpoints" => Int(getf(p, :armorpoints, 0)),
        "armortype" => Int(getf(p, :armortype, 0)),
        "ammo" => num_list(getf(p, :ammo, Int[]), 4),
        "maxammo" => num_list(getf(p, :maxammo, Int[]), 4),
        "weaponowned" => bool_list(getf(p, :weaponowned, Bool[]), 9),
        "pendingweapon" => Int(getf(p, :pendingweapon, 0)),
        "readyweapon" => Int(getf(p, :readyweapon, 0)),
        "cards" => bool_list(getf(p, :cards, Bool[]), 6),
        "cheats" => Int(getf(p, :cheats, 0)),
        "message" => string(getf(p, :message, "")),
        "message_tics" => Int(getf(p, :message_tics, 0)),
        "attackdown" => getf(p, :attackdown, false) == true,
        "usedown" => getf(p, :usedown, false) == true,
        "damagecount" => Int(getf(p, :damagecount, 0)),
        "bonuscount" => Int(getf(p, :bonuscount, 0)),
        "extralight" => Int(getf(p, :extralight, 0)),
        "refire" => Int(getf(p, :refire, 0)),
        "killcount" => Int(getf(p, :killcount, 0)),
        "itemcount" => Int(getf(p, :itemcount, 0)),
        "secretcount" => Int(getf(p, :secretcount, 0)),
        "didsecret" => getf(p, :didsecret, false) == true,
        "psprite_y" => Int(getf(p, :psprite_sy, 0)),
        "psprite_sy" => Int(getf(p, :psprite_sy, 0)),
        "psprite_state" => string(getf(p, :psprite_state, "")),
        "psprite_tics" => Int(getf(p, :psprite_tics, 0)),
        "psprite_step" => Int(getf(p, :psprite_step, 0)),
        "psprite_body" => string(getf(p, :psprite_body, "")),
        "psprite_flash" => string(getf(p, :psprite_flash, "")),
        "flash_tics" => Int(getf(p, :flash_tics, 0)),
        "powers" => num_list(getf(p, :powers, Int[]), 6),
    ]
end

function sector_index(world, sector)
    sector === nothing && return -1
    for (i, s) in enumerate(world.sectors)
        s === sector && return i - 1
    end
    -1
end

function dump_thinker(th, world)
    sec_i = sector_index(world, getf(th, :sector, nothing))
    sec_i < 0 && return nothing
    kind = string(getf(th, :kind, ""))
    if kind == "door"
        return [
            "kind" => "door", "sector" => sec_i, "type" => Int(getf(th, :type, 0)),
            "direction" => Int(getf(th, :direction, 0)), "topheight" => Int(getf(th, :topheight, 0)),
            "speed" => Int(getf(th, :speed, 0)), "topwait" => Int(getf(th, :topwait, 0)),
            "topcountdown" => Int(getf(th, :topcountdown, 0)),
        ]
    end
    if kind == "plat"
        return [
            "kind" => "plat", "sector" => sec_i, "type" => Int(getf(th, :type, 0)),
            "status" => Int(getf(th, :status, 0)), "speed" => Int(getf(th, :speed, 0)),
            "low" => Int(getf(th, :low, 0)), "high" => Int(getf(th, :high, 0)),
            "wait" => Int(getf(th, :wait, 0)), "count" => Int(getf(th, :count, 0)),
        ]
    end
    if kind == "floor"
        return [
            "kind" => "floor", "sector" => sec_i, "direction" => Int(getf(th, :direction, 0)),
            "dest" => Int(getf(th, :dest, 0)), "speed" => Int(getf(th, :speed, 0)),
        ]
    end
    nothing
end

function dump_state(game)
    world = game.world
    mobjs = world.mobjs
    mobj_rows = Any[dump_mobj(mo, mobjs) for mo in mobjs]
    sectors = Any[]
    for s in world.sectors
        push!(sectors, [
            "floorheight" => Int(s.floorheight), "ceilingheight" => Int(s.ceilingheight),
            "floorpic" => Int(s.floorpic), "ceilingpic" => Int(s.ceilingpic),
            "lightlevel" => Int(s.lightlevel), "special" => Int(s.special),
        ])
    end
    sides = Any[]
    for sd in world.sides
        push!(sides, [
            "textureoffset" => Int(sd.textureoffset), "rowoffset" => Int(sd.rowoffset),
            "toptexture" => Int(sd.toptexture), "bottomtexture" => Int(sd.bottomtexture),
            "midtexture" => Int(sd.midtexture),
        ])
    end
    lines = Any[]
    for ln in world.lines
        push!(lines, ["flags" => Int(ln.flags), "special" => Int(ln.special)])
    end
    thinkers = Any[]
    spec = getf(game, :specials, nothing)
    if spec !== nothing
        for th in getf(spec, :thinkers, [])
            getf(th, :dead, false) && continue
            rec = dump_thinker(th, world)
            rec !== nothing && push!(thinkers, rec)
        end
    end
    buttons = Any[]
    if spec !== nothing
        for btn in getf(spec, :buttons, [])
            line = getf(btn, :line, nothing)
            idx = line !== nothing ? Int(getf(line, :i_line, -1)) : -1
            push!(buttons, [
                "line" => idx, "where" => string(getf(btn, :attr, "toptexture")),
                "texture" => Int(getf(btn, :texture, 0)), "timer" => Int(getf(btn, :timer, 0)),
            ])
        end
    end
    [
        "episode" => Int(getf(game, :episode, 1)),
        "mapn" => Int(getf(game, :mapn, 1)),
        "skill" => Int(getf(game, :skill, 2)),
        "leveltime" => Int(getf(game, :leveltime, 0)),
        "player" => dump_player(game.player),
        "sectors" => sectors,
        "sides" => sides,
        "lines" => lines,
        "mobjs" => mobj_rows,
        "thinkers" => thinkers,
        "buttons" => buttons,
        "totalkills" => Int(getf(game, :totalkills, 0)),
        "totalitems" => Int(getf(game, :totalitems, 0)),
        "totalsecret" => Int(getf(game, :totalsecret, 0)),
    ]
end

function write_save(game, slot, description)
    (game.world === nothing || game.player === nothing) && return false
    payload = enc(dump_state(game))
    blob = pad_desc(description) * MAGIC * payload
    dest = path(game, slot)
    tmp = dest * ".tmp"
    try
        write(tmp, blob)
        isfile(dest) && rm(dest)
        mv(tmp, dest)
    catch
        return false
    end
    true
end

function read_save(game, slot)
    p = path(game, slot)
    isfile(p) || return nothing
    data = String(read(p))
    need = SAVESTRINGSIZE + ncodeunits(MAGIC)
    ncodeunits(data) < need && return nothing
    data[SAVESTRINGSIZE + 1:need] != MAGIC && return nothing
    decode(data[need + 1:end])
end

function copy_nums!(dst, src)
    src === nothing && return
    for i in 1:min(length(dst), length(src))
        dst[i] = Int(src[i])
    end
end

function take(rec, name, fallback)
    haskey(rec, name) && rec[name] !== nothing && return rec[name]
    fallback
end

function apply_player!(player, rec)
    rec === nothing && return
    player.playerstate = Int(take(rec, "playerstate", player.playerstate))
    player.viewz = Int(take(rec, "viewz", player.viewz))
    player.viewheight = Int(take(rec, "viewheight", player.viewheight))
    player.deltaviewheight = Int(take(rec, "deltaviewheight", player.deltaviewheight))
    player.bob = Int(take(rec, "bob", player.bob))
    player.health = Int(take(rec, "health", player.health))
    player.armorpoints = Int(take(rec, "armorpoints", player.armorpoints))
    player.armortype = Int(take(rec, "armortype", player.armortype))
    haskey(rec, "ammo") && copy_nums!(player.ammo, rec["ammo"])
    haskey(rec, "maxammo") && copy_nums!(player.maxammo, rec["maxammo"])
    if haskey(rec, "weaponowned") && rec["weaponowned"] !== nothing
        for i in 1:min(length(player.weaponowned), length(rec["weaponowned"]))
            player.weaponowned[i] = rec["weaponowned"][i] == true
        end
    end
    player.pendingweapon = Int(take(rec, "pendingweapon", player.pendingweapon))
    player.readyweapon = Int(take(rec, "readyweapon", player.readyweapon))
    if haskey(rec, "cards") && rec["cards"] !== nothing
        for i in 1:min(length(player.cards), length(rec["cards"]))
            player.cards[i] = rec["cards"][i] == true
        end
    end
    player.cheats = Int(take(rec, "cheats", player.cheats))
    player.message = string(take(rec, "message", ""))
    player.message_tics = Int(take(rec, "message_tics", 0))
    player.attackdown = get(rec, "attackdown", false) == true
    player.usedown = get(rec, "usedown", false) == true
    player.damagecount = Int(take(rec, "damagecount", 0))
    player.bonuscount = Int(take(rec, "bonuscount", 0))
    player.extralight = Int(take(rec, "extralight", 0))
    player.refire = Int(take(rec, "refire", 0))
    player.killcount = Int(take(rec, "killcount", 0))
    player.itemcount = Int(take(rec, "itemcount", 0))
    player.secretcount = Int(take(rec, "secretcount", 0))
    player.psprite_sy = Int(take(rec, "psprite_sy", player.psprite_sy))
    player.psprite_state = string(take(rec, "psprite_state", player.psprite_state))
    player.psprite_tics = Int(take(rec, "psprite_tics", player.psprite_tics))
    player.psprite_step = Int(take(rec, "psprite_step", 0))
    player.psprite_body = string(take(rec, "psprite_body", ""))
    player.psprite_flash = string(take(rec, "psprite_flash", ""))
    player.flash_tics = Int(take(rec, "flash_tics", 0))
    haskey(rec, "powers") && copy_nums!(player.powers, rec["powers"])
    player.mo !== nothing && (player.mo.health = player.health)
    nothing
end

function apply_mobj!(mo, rec)
    mo.x = Int(get(rec, "x", mo.x))
    mo.y = Int(get(rec, "y", mo.y))
    mo.z = Int(get(rec, "z", mo.z))
    mo.angle = as_u32(get(rec, "angle", mo.angle))
    mo.momx = Int(get(rec, "momx", 0))
    mo.momy = Int(get(rec, "momy", 0))
    mo.momz = Int(get(rec, "momz", 0))
    mo.floorz = Int(get(rec, "floorz", mo.floorz))
    mo.ceilingz = Int(get(rec, "ceilingz", mo.ceilingz))
    mo.flags = Int(get(rec, "flags", mo.flags))
    mo.health = Int(get(rec, "health", mo.health))
    haskey(rec, "sprite") && rec["sprite"] !== nothing && (mo.sprite = string(rec["sprite"]))
    mo.alive = get(rec, "alive", true) != false
    mo.reactiontime = Int(get(rec, "reactiontime", 0))
    mo.movedir = Int(get(rec, "movedir", mo.movedir))
    mo.movecount = Int(get(rec, "movecount", 0))
    mo.frame = Int(get(rec, "frame", 0))
    mo.tics = Int(get(rec, "tics", mo.tics))
    hasproperty(mo, :damage) && (mo.damage = Int(get(rec, "damage", mo.damage)))
    get(rec, "istate", nothing) isa Integer && (mo.istate = Int(rec["istate"]))
    nothing
end

function apply_save!(game, data)
    (data === nothing || game.start_level === nothing) && return false
    game.carry = nothing
    game.episode = Int(get(data, "episode", game.episode))
    game.mapn = Int(get(data, "mapn", game.mapn))
    game.skill = Int(get(data, "skill", game.skill))
    game.start_level(game)
    (game.world === nothing || game.player === nothing) && return false
    game.leveltime = Int(get(data, "leveltime", 0))
    game.totalkills = Int(get(data, "totalkills", game.totalkills))
    game.totalitems = Int(get(data, "totalitems", game.totalitems))
    game.totalsecret = Int(get(data, "totalsecret", game.totalsecret))
    world = game.world
    for (i, rec) in enumerate(get(data, "sectors", Any[]))
        i > length(world.sectors) && break
        s = world.sectors[i]
        s.floorheight = Int(get(rec, "floorheight", s.floorheight))
        s.ceilingheight = Int(get(rec, "ceilingheight", s.ceilingheight))
        s.floorpic = Int(get(rec, "floorpic", s.floorpic))
        s.ceilingpic = Int(get(rec, "ceilingpic", s.ceilingpic))
        s.lightlevel = Int(get(rec, "lightlevel", s.lightlevel))
        s.special = Int(get(rec, "special", s.special))
    end
    for (i, rec) in enumerate(get(data, "sides", Any[]))
        i > length(world.sides) && break
        sd = world.sides[i]
        sd.textureoffset = Int(get(rec, "textureoffset", sd.textureoffset))
        sd.rowoffset = Int(get(rec, "rowoffset", sd.rowoffset))
        sd.toptexture = Int(get(rec, "toptexture", sd.toptexture))
        sd.bottomtexture = Int(get(rec, "bottomtexture", sd.bottomtexture))
        sd.midtexture = Int(get(rec, "midtexture", sd.midtexture))
    end
    for (i, rec) in enumerate(get(data, "lines", Any[]))
        i > length(world.lines) && break
        ln = world.lines[i]
        ln.flags = Int(get(rec, "flags", ln.flags))
        ln.special = Int(get(rec, "special", ln.special))
    end
    where_attr = Dict(
        "top" => "toptexture", "middle" => "midtexture", "bottom" => "bottomtexture",
        "toptexture" => "toptexture", "midtexture" => "midtexture", "bottomtexture" => "bottomtexture",
    )
    spec = game.specials
    if spec !== nothing
        for rec in get(data, "thinkers", Any[])
            sec_i = Int(get(rec, "sector", -1))
            (sec_i < 0 || sec_i + 1 > length(world.sectors)) && continue
            sector = world.sectors[sec_i + 1]
            kind = string(get(rec, "kind", ""))
            (kind == "door" || kind == "plat" || kind == "floor") || continue
            th = (
                kind = kind, sector = sector, type = Int(get(rec, "type", 0)),
                direction = Int(get(rec, "direction", 0)), topheight = Int(get(rec, "topheight", 0)),
                speed = Int(get(rec, "speed", 0)), topwait = Int(get(rec, "topwait", 0)),
                topcountdown = Int(get(rec, "topcountdown", 0)), status = Int(get(rec, "status", 0)),
                low = Int(get(rec, "low", 0)), high = Int(get(rec, "high", 0)),
                wait = Int(get(rec, "wait", 0)), count = Int(get(rec, "count", 0)),
                dest = Int(get(rec, "dest", 0)), dead = false,
            )
            sector.specialdata = th
            push!(spec.thinkers, th)
        end
        for rec in get(data, "buttons", Any[])
            li = Int(get(rec, "line", -1))
            (li < 0 || li + 1 > length(world.lines)) && continue
            push!(spec.buttons, (
                line = world.lines[li + 1],
                attr = get(where_attr, string(get(rec, "where", "")), "toptexture"),
                texture = Int(get(rec, "texture", 0)),
                timer = Int(get(rec, "timer", 0)),
            ))
        end
    end
    recs = get(data, "mobjs", Any[])
    n = min(length(recs), length(world.mobjs))
    for i in 1:n
        apply_mobj!(world.mobjs[i], recs[i])
        set_thing_position!(world, world.mobjs[i])
    end
    for i in 1:n
        ti = get(recs[i], "target", nothing)
        if ti isa Integer && ti >= 0 && ti < length(world.mobjs)
            world.mobjs[i].target = world.mobjs[ti + 1]
        end
    end
    apply_player!(game.player, get(data, "player", nothing))
    game.gamestate = "view"
    true
end

function load_save(game, slot)
    data = read_save(game, slot)
    data === nothing && return false
    apply_save!(game, data)
end

end

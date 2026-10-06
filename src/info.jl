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
# Estados e tipos das coisas, a partir de info.py. O numero continua 0-based.

module Info

include(joinpath(@__DIR__, "info_data.jl"))

export MOBJINFO, STATES, ACTIONS, SPRNAMES, BY_DOOMED
export mobj_type_for_doomednum, info_at, state_at, action_name, spr_name

mobj_type_for_doomednum(n) = get(BY_DOOMED, Int(n), -1)
info_at(typ) = MOBJINFO[typ + 1]
state_at(n) = STATES[n + 1]
action_name(n) = (0 <= n < length(ACTIONS)) ? ACTIONS[n + 1] : ""
spr_name(n) = SPRNAMES[n + 1]

for n in names(@__MODULE__, all=true)
    s = string(n)
    if startswith(s, "S_") || startswith(s, "MT_") || startswith(s, "MI_")
        @eval export $n
    end
end

end

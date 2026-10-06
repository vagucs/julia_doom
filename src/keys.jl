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
# Nomes de tecla a partir do SDL_Keycode.

module Keys

export name_of

const MASK = 1073741824

const NAMED = Dict{Int,String}(
    27 => "escape",
    13 => "return",
    9 => "tab",
    8 => "backspace",
    32 => "space",
    44 => "comma",
    46 => "period",
    45 => "minus",
    61 => "equals",
    MASK + 79 => "right",
    MASK + 80 => "left",
    MASK + 81 => "down",
    MASK + 82 => "up",
    MASK + 86 => "minus",
    MASK + 87 => "equals",
    MASK + 88 => "return",
    MASK + 224 => "ctrl",
    MASK + 228 => "ctrl",
    MASK + 225 => "shift",
    MASK + 229 => "shift",
    MASK + 226 => "alt",
    MASK + 230 => "alt",
)

function name_of(sym::Integer)
    sym = Int(sym)
    sym == 0 && return "quit"
    key = get(NAMED, sym, "")
    key != "" && return key
    if MASK + 58 <= sym <= MASK + 69
        return "f$(sym - (MASK + 58) + 1)"
    end
    if (97 <= sym <= 122) || (48 <= sym <= 57)
        return string(Char(sym))
    end
    ""
end

end

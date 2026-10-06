# julia_doom

![DOOM rodando em Julia com SDL2](screenshot/doom.png)

**Vídeo:** [DOOM rodando em Julia](https://youtu.be/jITQFpVyCeA)

**Repositório:** [github.com/vagucs/julia_doom](https://github.com/vagucs/julia_doom)

DOOM generic portado de **[python_doom](https://github.com/vagucs/python_doom)** para **Julia + SDL2**.

Por **Wagner Nunes da Silva**

- vagucs@bol.com.br
- vagucs@vagucs.com.br
- vagucs@gmail.com
- [www.vagucs.com.br](https://www.vagucs.com.br)
- [LinkedIn](https://www.linkedin.com/in/wagner-nunes-da-silva-b0a15360)

Esta árvore é aquele motor em Python, agora em Julia. O laço, o mapa e o renderer ficam em Julia. O `ccall` fala com a `SDL2.dll` para a janela, o teclado, o rato e a fila de PCM. Não há renderer em C. O MCI do Windows toca o MIDI, porque a SDL2 não toca.

English version: [README.md](README.md)

---

## O que é este projeto

`python_doom` é um motor de DOOM condensado e jogável, em Python. Este diretório é a **mesma peça de estudo**, reescrita em Julia:

- Janela, teclas, rato, PCM: **SDL2**, chamada do Julia com `ccall`
- Framebuffer: 320×200, um índice da PLAYPAL por byte (`Vector{UInt8}` de 64000), esticado numa janela de 640×400
- Tic: 35 Hz (`TICRATE`). Cada quadro mostrado corre até 4 tics
- Renderer: BSP, visplanes, colunas, spans, sprites, o sprite da arma
- Mapa: VERTEXES, LINEDEFS, SIDEDEFS, SECTORS, SEGS, SSECTORS, NODES, THINGS, BLOCKMAP, REJECT
- Jogo: andar, portas, elevadores, interruptores, saída, itens, armas, barra, automapa no Tab, som `DS*`, música MUS→MIDI, menu no Esc, contagem, derretimento ao trocar de fase, inimigos que olham, perseguem e atacam, rato que olha

É preciso um IWAD legal (shareware `doom1.wad` ou comercial `doom.wad` / `doom2.wad`). Este repositório não traz WAD comercial.

É um **port educacional condensado**: o motor é Julia, a camada nativa é só a SDL2 e a chamada de MIDI do Windows.

Fora desta árvore:

- Rede, joystick, CD de áudio

---

## Proposta educacional

Este projeto é uma **peça de estudo**. O port em Python já tirou o pré-processador e os arrays 1-based do Harbour. O port em Julia pergunta outra coisa: **o que muda quando a linguagem tem estouro de 32 bits de verdade, arrays 1-based, e `ccall` no lugar do pygame**.

O que ele pretende ensinar:

- **Python, depois Julia.** Abra `python_doom/doom/` ao lado de `julia_doom/src/`. Os nomes ficam perto (`thrust!`, `fixed_mul`, `line_attack`) para os dois arquivos ficarem lado a lado.
- **Estouro de 32 bits, já no tipo.** `Int32` e `UInt32` estouram. Um `Int` solto é `Int64`, então a conta do jogo passa por `as_i32` / `as_u32`. `fixed_mul` alarga para `Int64` e volta. `fixed_div` usa divisão para baixo, como o `//` do Python.
- **Leitura 1-based.** Lumps do WAD, nós da BSP, linhas do menu e colunas da tela continuam 0-based nos dados e são lidos com `+ 1`.
- **Onde o Julia basta.** Colunas, chão, sprites, thinkers e as scanlines do `-crt` rodam em Julia. A SDL2 é a janela, o teclado, o rato e a fila de PCM.

Caminho sugerido:

1. Rode `run.bat` e leia `run.jl` e `src/game.jl` — arranque, tic, entrada.
2. Compare `src/compat.jl` com `python_doom/doom/compat.py`.
3. Abra `src/render.jl` ao lado de `python_doom/doom/render.py`.
4. Siga uma porta do **Espaço** (`use_lines` em `src/collision.jl`) até `src/specials.jl`.
5. Siga um tiro do **Ctrl** em `src/player.jl` até `spawn_player_missile` em `src/enemy.jl`.

---

## De Python para Julia

Listas em Python são 0-based. Arrays em Julia são 1-based. Lumps do WAD, nós da BSP, linhas do menu e faixas de clip continuam 0-based nos dados e são lidos com `+ 1`.

| Python (`python_doom`) | Julia (`julia_doom`) |
| --- | --- |
| `thing.x` | `thing.x` |
| `None` | `nothing` |
| `items[0]` | `items[1]` |
| classe | `mutable struct` (referência compartilhada) |
| `int` sem limite | `Int32` / `UInt32` estouram; um `Int` solto é `Int64` |
| `&`, `\|`, `^` | `&`, `\|`, `⊻` em `UInt32`, ou `band` / `bor` / `bxor` |
| `x >> n` | `ushr` / `shar` |
| `fixed_mul` / `fixed_div` | `fixed_mul` / `fixed_div` (`fld`, igual ao `//`) |
| framebuffer `bytearray` | `Vector{UInt8}`, um índice de paleta por pixel |
| pygame | SDL2 via `ccall` |
| `(-1) % n` arredonda para baixo | `(-1) % n` fica negativo; `mod` arredonda para baixo |
| `if 0` | erro de tipo; compare `!= 0` |

`0` não é booleano. Atualizar um campo de um `mutable struct` aparece para quem chamou, do mesmo jeito que um objeto em Python.

### Lado a lado: `P_Thrust`

Python (`doom/player.py`):

```python
def thrust(mo, angle, move):
    mo.momx += fixed_mul(move, fine_cos(angle))
    mo.momy += fixed_mul(move, fine_sin(angle))
```

Julia (`src/player.jl`):

```julia
function thrust!(mo, angle, move)
    mo.momx += Int(fixed_mul(move, fine_cos(angle)))
    mo.momy += Int(fixed_mul(move, fine_sin(angle)))
    nothing
end
```

`.` continua `.`. `mo` é um struct mutável, então o impulso novo fica no mobj que quem chamou já tem. O `!` marca essa mutação. `Int(...)` grava o produto na largura do campo.

---

## Tecnologia

| Camada | Este port | Python (`python_doom`) |
| --- | --- | --- |
| Linguagem | Julia 1.13 (o `run.bat` usa o executável do juliaup) | Python 3.10+ |
| Janela, teclas, rato, PCM | SDL2, `ccall` na `SDL2.dll` | pygame 2.x |
| Blit da paleta / CRT | Julia, depois `SDL_UpdateTexture` | numpy |
| MIDI (Windows) | winmm `mciSendStringW` | a mesma ideia, fora do pygame |
| IWAD | os mesmos lumps | os mesmos lumps |
| Build | nenhum (`run.bat` ou `julia --project=. run.jl`) | `pip install -r requirements.txt` |

O renderer é Julia. Não há arquivo em C para compilar.

---

## Como rodar

Neste diretório, no Windows:

```
run.bat
run.bat -iwad ..\DOOM1.WAD
run.bat -fps -warp 1 1
run.bat -crt
run.bat -novsync
```

O `run.bat` põe `C:\msys64\ucrt64\bin` no `PATH` e abre o Julia 1.13. A janela nasce em 640×400. Sem `-crt`, a textura de 320×200 é esticada em nearest-neighbor. `-novsync` pede o present sem esperar o monitor e tira a pausa de 1 ms entre as leituras.

Sem `-iwad`, a busca olha `DOOM1.WAD` nesta pasta e na pasta pai.

---

## Teclas

Controles clássicos do DOOM.

### Movimento e ações

| Tecla | Ação |
| --- | --- |
| Setas | Frente, trás, virar |
| **Shift** | Correr |
| **Alt** | Andar de lado (segurar) |
| **Ctrl** ou botão esquerdo | Atirar |
| **Espaço** / **E** | Usar / abrir porta |
| Rato | Olhar |
| **Enter** / **Esc** | Menu |
| **Tab** | Automapa. **F** segue, **G** desenha a grade, **0** mostra o mapa inteiro |
| **-** / **=** | Zoom do automapa quando ele está aberto; senão, vista 3D menor / maior |
| **F11** | Liga ou desliga os quadros por segundo |
| **Alt+Enter** | Tela cheia |

Fechar a janela sai. **Y** confirma a saída no menu.

### Truques

Digite durante a fase, com o menu fechado. Sem Enter. No pesadelo só **IDCLEV** e **IDDT** entram.

| Código | Efeito |
| --- | --- |
| **IDDQD** | Modo deus |
| **IDKFA** | Todas as armas, munição, chaves e armadura |
| **IDFA** | Armas, munição e armadura |
| **IDCLIP** / **IDSPISPOPD** | Sem colisão |
| **IDDT** | Automapa: todas as paredes, depois as coisas |
| **IDBEHOLD** | Power-ups; depois **V** **S** **I** **R** **A** **L** |
| **IDCHOPPERS** | Motosserra |
| **IDMYPOS** | Coordenadas e ângulo |
| **IDCLEV** + 2 dígitos | Warp (`11` = E1M1, ou MAP11 num IWAD comercial) |
| **IDMUS** + 2 dígitos | Troca a música |

`-nocheats` desliga os códigos.

---

## Parâmetros de linha de comando

### IWAD

| Parâmetro | Descrição |
| --- | --- |
| `-iwad file.wad` | IWAD a carregar |
| `file.wad` | A mesma coisa, sem `-iwad` |
| `-file wad [wad…]` | PWADs extras depois do IWAD |

### Vídeo

| Parâmetro | Descrição |
| --- | --- |
| `-crt` | Scanlines, desenhadas em Julia sobre a textura da SDL |
| `-fps` | Quadros por segundo no canto superior direito. O jogo continua em 35 Hz |
| `-novsync` | Apresenta sem esperar o monitor e tira a pausa de 1 ms |

### Jogo

| Parâmetro | Descrição |
| --- | --- |
| `-warp e m` | Pula o título e começa o episódio `e` mapa `m` |
| `-skill n` | Skill |
| `-nomonsters` | Não spawna inimigos |
| `-fast` | Monstros mais rápidos |
| `-respawn` | Respawn estilo pesadelo |
| `-nosound` | Sem efeitos |
| `-nomusic` | Sem MIDI |
| `-nocheats` | Ignora os truques |

Trocar de fase derrete a tela. Um jogo novo a partir do título não derrete. O mapa 8 do shareware escreve o texto do episódio em `FLOOR4_8`. Os saves são `doomsavN.dsg` ao lado do IWAD, com o cabeçalho `DOOMPY01`.

---

## Estrutura

```
run.jl               entrada
run.bat              PATH, depois o Julia
src/                 motor
screenshot/doom.png  a imagem do topo
```

| Caminho | Python |
| --- | --- |
| `src/compat.jl` | `doom/compat.py` |
| `src/wad.jl` | `doom/wad.py` |
| `src/video.jl` | `doom/video.py` |
| `src/v_video.jl` | `doom/v_video.py` |
| `src/tables.jl` | `doom/tables.py` |
| `src/r_data.jl` | `doom/r_data.py` |
| `src/render.jl` | `doom/render.py` |
| `src/world.jl` | `doom/world.py` |
| `src/collision.jl` | `doom/collision.py` |
| `src/player.jl` | `doom/player.py` |
| `src/specials.jl` | `doom/specials.py` |
| `src/info.jl` | `doom/info.py` |
| `src/sprites.jl` | `doom/sprites.py` |
| `src/enemy.jl` | `doom/enemy.py` |
| `src/thinker.jl` | `doom/thinker.py` |
| `src/status.jl` | `doom/status.py` |
| `src/sound.jl` | `doom/sound.py` |
| `src/mus2mid.jl` | `doom/mus2mid.py` |
| `src/menu.jl` | `doom/menu.py` |
| `src/wi_stuff.jl` | `doom/wi_stuff.py` |
| `src/wipe.jl` | `doom/wipe.py` |
| `src/cheats.jl` | a máquina de truques em `doom/game.py` |
| `src/am_map.jl` | `doom/am_map.py` |
| `src/finale.jl` | `doom/finale.py` |
| `src/saveg.jl` | `doom/saveg.py` |
| `src/game.jl` | `doom/game.py` |
| `run.jl` | a entrada do Python |

---

## Linhagem

1. **[python_doom](https://github.com/vagucs/python_doom)** — Python + pygame
2. **[julia_doom](https://github.com/vagucs/julia_doom)** — Julia + SDL2 (esta árvore)

---

## Doe

### Patrocínio no GitHub

[github.com/sponsors/vagucs](https://github.com/sponsors/vagucs)

### Ethereum

`0x1b64038A2b1DB73ABd0068d8B9B0d1dC5a90C5F1`

![QR Code Ethereum](docs/qr-ethereum.png)

### PIX

Chave: `vagucs@bol.com.br`

![QR Code PIX](docs/qr-pix.png)

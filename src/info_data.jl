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
# Tabelas de info.c, geradas de info.lua. O indice do estado continua 0-based na conta.
const SPRNAMES = [
    "TROO",
    "SHTG",
    "PUNG",
    "PISG",
    "PISF",
    "SHTF",
    "SHT2",
    "CHGG",
    "CHGF",
    "MISG",
    "MISF",
    "SAWG",
    "PLSG",
    "PLSF",
    "BFGG",
    "BFGF",
    "BLUD",
    "PUFF",
    "BAL1",
    "BAL2",
    "PLSS",
    "PLSE",
    "MISL",
    "BFS1",
    "BFE1",
    "BFE2",
    "TFOG",
    "IFOG",
    "PLAY",
    "POSS",
    "SPOS",
    "VILE",
    "FIRE",
    "FATB",
    "FBXP",
    "SKEL",
    "MANF",
    "FATT",
    "CPOS",
    "SARG",
    "HEAD",
    "BAL7",
    "BOSS",
    "BOS2",
    "SKUL",
    "SPID",
    "BSPI",
    "APLS",
    "APBX",
    "CYBR",
    "PAIN",
    "SSWV",
    "KEEN",
    "BBRN",
    "BOSF",
    "ARM1",
    "ARM2",
    "BAR1",
    "BEXP",
    "FCAN",
    "BON1",
    "BON2",
    "BKEY",
    "RKEY",
    "YKEY",
    "BSKU",
    "RSKU",
    "YSKU",
    "STIM",
    "MEDI",
    "SOUL",
    "PINV",
    "PSTR",
    "PINS",
    "MEGA",
    "SUIT",
    "PMAP",
    "PVIS",
    "CLIP",
    "AMMO",
    "ROCK",
    "BROK",
    "CELL",
    "CELP",
    "SHEL",
    "SBOX",
    "BPAK",
    "BFUG",
    "MGUN",
    "CSAW",
    "LAUN",
    "PLAS",
    "SHOT",
    "SGN2",
    "COLU",
    "SMT2",
    "GOR1",
    "POL2",
    "POL5",
    "POL4",
    "POL3",
    "POL1",
    "POL6",
    "GOR2",
    "GOR3",
    "GOR4",
    "GOR5",
    "SMIT",
    "COL1",
    "COL2",
    "COL3",
    "COL4",
    "CAND",
    "CBRA",
    "COL6",
    "TRE1",
    "TRE2",
    "ELEC",
    "CEYE",
    "FSKU",
    "COL5",
    "TBLU",
    "TGRN",
    "TRED",
    "SMBT",
    "SMGT",
    "SMRT",
    "HDB1",
    "HDB2",
    "HDB3",
    "HDB4",
    "HDB5",
    "HDB6",
    "POB1",
    "POB2",
    "BRS1",
    "TLMP",
    "TLP2",
]
mutable struct StateRec
    sprite::Int
    frame::Int
    tics::Int
    action::Int
    nxt::Int
end
const STATES = StateRec[
    StateRec(0, 0, -1, 0, 0),
    StateRec(1, 4, 0, 1, 0),
    StateRec(2, 0, 1, 2, 2),
    StateRec(2, 0, 1, 3, 3),
    StateRec(2, 0, 1, 4, 4),
    StateRec(2, 1, 4, 0, 6),
    StateRec(2, 2, 4, 5, 7),
    StateRec(2, 3, 5, 0, 8),
    StateRec(2, 2, 4, 0, 9),
    StateRec(2, 1, 5, 6, 2),
    StateRec(3, 0, 1, 2, 10),
    StateRec(3, 0, 1, 3, 11),
    StateRec(3, 0, 1, 4, 12),
    StateRec(3, 0, 4, 0, 14),
    StateRec(3, 1, 6, 7, 15),
    StateRec(3, 2, 4, 0, 16),
    StateRec(3, 1, 5, 6, 10),
    StateRec(4, 32768, 7, 8, 1),
    StateRec(1, 0, 1, 2, 18),
    StateRec(1, 0, 1, 3, 19),
    StateRec(1, 0, 1, 4, 20),
    StateRec(1, 0, 3, 0, 22),
    StateRec(1, 0, 7, 9, 23),
    StateRec(1, 1, 5, 0, 24),
    StateRec(1, 2, 5, 0, 25),
    StateRec(1, 3, 4, 0, 26),
    StateRec(1, 2, 5, 0, 27),
    StateRec(1, 1, 5, 0, 28),
    StateRec(1, 0, 3, 0, 29),
    StateRec(1, 0, 7, 6, 18),
    StateRec(5, 32768, 4, 8, 31),
    StateRec(5, 32769, 3, 10, 1),
    StateRec(6, 0, 1, 2, 32),
    StateRec(6, 0, 1, 3, 33),
    StateRec(6, 0, 1, 4, 34),
    StateRec(6, 0, 3, 0, 36),
    StateRec(6, 0, 7, 11, 37),
    StateRec(6, 1, 7, 0, 38),
    StateRec(6, 2, 7, 12, 39),
    StateRec(6, 3, 7, 13, 40),
    StateRec(6, 4, 7, 0, 41),
    StateRec(6, 5, 7, 14, 42),
    StateRec(6, 6, 6, 0, 43),
    StateRec(6, 7, 6, 15, 44),
    StateRec(6, 0, 5, 6, 32),
    StateRec(6, 1, 7, 0, 46),
    StateRec(6, 0, 3, 0, 33),
    StateRec(6, 32776, 5, 8, 48),
    StateRec(6, 32777, 4, 10, 1),
    StateRec(7, 0, 1, 2, 49),
    StateRec(7, 0, 1, 3, 50),
    StateRec(7, 0, 1, 4, 51),
    StateRec(7, 0, 4, 16, 53),
    StateRec(7, 1, 4, 16, 54),
    StateRec(7, 1, 0, 6, 49),
    StateRec(8, 32768, 5, 8, 1),
    StateRec(8, 32769, 5, 10, 1),
    StateRec(9, 0, 1, 2, 57),
    StateRec(9, 0, 1, 3, 58),
    StateRec(9, 0, 1, 4, 59),
    StateRec(9, 1, 8, 17, 61),
    StateRec(9, 1, 12, 18, 62),
    StateRec(9, 1, 0, 6, 57),
    StateRec(10, 32768, 3, 8, 64),
    StateRec(10, 32769, 4, 0, 65),
    StateRec(10, 32770, 4, 10, 66),
    StateRec(10, 32771, 4, 10, 1),
    StateRec(11, 2, 4, 2, 68),
    StateRec(11, 3, 4, 2, 67),
    StateRec(11, 2, 1, 3, 69),
    StateRec(11, 2, 1, 4, 70),
    StateRec(11, 0, 4, 19, 72),
    StateRec(11, 1, 4, 19, 73),
    StateRec(11, 1, 0, 6, 67),
    StateRec(12, 0, 1, 2, 74),
    StateRec(12, 0, 1, 3, 75),
    StateRec(12, 0, 1, 4, 76),
    StateRec(12, 0, 3, 20, 78),
    StateRec(12, 1, 20, 6, 74),
    StateRec(13, 32768, 4, 8, 1),
    StateRec(13, 32769, 4, 8, 1),
    StateRec(14, 0, 1, 2, 81),
    StateRec(14, 0, 1, 3, 82),
    StateRec(14, 0, 1, 4, 83),
    StateRec(14, 0, 20, 21, 85),
    StateRec(14, 1, 10, 17, 86),
    StateRec(14, 1, 10, 22, 87),
    StateRec(14, 1, 20, 6, 81),
    StateRec(15, 32768, 11, 8, 89),
    StateRec(15, 32769, 6, 10, 1),
    StateRec(16, 2, 8, 0, 91),
    StateRec(16, 1, 8, 0, 92),
    StateRec(16, 0, 8, 0, 0),
    StateRec(17, 32768, 4, 0, 94),
    StateRec(17, 1, 4, 0, 95),
    StateRec(17, 2, 4, 0, 96),
    StateRec(17, 3, 4, 0, 0),
    StateRec(18, 32768, 4, 0, 98),
    StateRec(18, 32769, 4, 0, 97),
    StateRec(18, 32770, 6, 0, 100),
    StateRec(18, 32771, 6, 0, 101),
    StateRec(18, 32772, 6, 0, 0),
    StateRec(19, 32768, 4, 0, 103),
    StateRec(19, 32769, 4, 0, 102),
    StateRec(19, 32770, 6, 0, 105),
    StateRec(19, 32771, 6, 0, 106),
    StateRec(19, 32772, 6, 0, 0),
    StateRec(20, 32768, 6, 0, 108),
    StateRec(20, 32769, 6, 0, 107),
    StateRec(21, 32768, 4, 0, 110),
    StateRec(21, 32769, 4, 0, 111),
    StateRec(21, 32770, 4, 0, 112),
    StateRec(21, 32771, 4, 0, 113),
    StateRec(21, 32772, 4, 0, 0),
    StateRec(22, 32768, 1, 0, 114),
    StateRec(23, 32768, 4, 0, 116),
    StateRec(23, 32769, 4, 0, 115),
    StateRec(24, 32768, 8, 0, 118),
    StateRec(24, 32769, 8, 0, 119),
    StateRec(24, 32770, 8, 23, 120),
    StateRec(24, 32771, 8, 0, 121),
    StateRec(24, 32772, 8, 0, 122),
    StateRec(24, 32773, 8, 0, 0),
    StateRec(25, 32768, 8, 0, 124),
    StateRec(25, 32769, 8, 0, 125),
    StateRec(25, 32770, 8, 0, 126),
    StateRec(25, 32771, 8, 0, 0),
    StateRec(22, 32769, 8, 24, 128),
    StateRec(22, 32770, 6, 0, 129),
    StateRec(22, 32771, 4, 0, 0),
    StateRec(26, 32768, 6, 0, 131),
    StateRec(26, 32769, 6, 0, 132),
    StateRec(26, 32768, 6, 0, 133),
    StateRec(26, 32769, 6, 0, 134),
    StateRec(26, 32770, 6, 0, 135),
    StateRec(26, 32771, 6, 0, 136),
    StateRec(26, 32772, 6, 0, 137),
    StateRec(26, 32773, 6, 0, 138),
    StateRec(26, 32774, 6, 0, 139),
    StateRec(26, 32775, 6, 0, 140),
    StateRec(26, 32776, 6, 0, 141),
    StateRec(26, 32777, 6, 0, 0),
    StateRec(27, 32768, 6, 0, 143),
    StateRec(27, 32769, 6, 0, 144),
    StateRec(27, 32768, 6, 0, 145),
    StateRec(27, 32769, 6, 0, 146),
    StateRec(27, 32770, 6, 0, 147),
    StateRec(27, 32771, 6, 0, 148),
    StateRec(27, 32772, 6, 0, 0),
    StateRec(28, 0, -1, 0, 0),
    StateRec(28, 0, 4, 0, 151),
    StateRec(28, 1, 4, 0, 152),
    StateRec(28, 2, 4, 0, 153),
    StateRec(28, 3, 4, 0, 150),
    StateRec(28, 4, 12, 0, 149),
    StateRec(28, 32773, 6, 0, 154),
    StateRec(28, 6, 4, 0, 157),
    StateRec(28, 6, 4, 25, 149),
    StateRec(28, 7, 10, 0, 159),
    StateRec(28, 8, 10, 26, 160),
    StateRec(28, 9, 10, 27, 161),
    StateRec(28, 10, 10, 0, 162),
    StateRec(28, 11, 10, 0, 163),
    StateRec(28, 12, 10, 0, 164),
    StateRec(28, 13, -1, 0, 0),
    StateRec(28, 14, 5, 0, 166),
    StateRec(28, 15, 5, 28, 167),
    StateRec(28, 16, 5, 27, 168),
    StateRec(28, 17, 5, 0, 169),
    StateRec(28, 18, 5, 0, 170),
    StateRec(28, 19, 5, 0, 171),
    StateRec(28, 20, 5, 0, 172),
    StateRec(28, 21, 5, 0, 173),
    StateRec(28, 22, -1, 0, 0),
    StateRec(29, 0, 10, 29, 175),
    StateRec(29, 1, 10, 29, 174),
    StateRec(29, 0, 4, 30, 177),
    StateRec(29, 0, 4, 30, 178),
    StateRec(29, 1, 4, 30, 179),
    StateRec(29, 1, 4, 30, 180),
    StateRec(29, 2, 4, 30, 181),
    StateRec(29, 2, 4, 30, 182),
    StateRec(29, 3, 4, 30, 183),
    StateRec(29, 3, 4, 30, 176),
    StateRec(29, 4, 10, 31, 185),
    StateRec(29, 5, 8, 32, 186),
    StateRec(29, 4, 8, 0, 176),
    StateRec(29, 6, 3, 0, 188),
    StateRec(29, 6, 3, 25, 176),
    StateRec(29, 7, 5, 0, 190),
    StateRec(29, 8, 5, 33, 191),
    StateRec(29, 9, 5, 27, 192),
    StateRec(29, 10, 5, 0, 193),
    StateRec(29, 11, -1, 0, 0),
    StateRec(29, 12, 5, 0, 195),
    StateRec(29, 13, 5, 28, 196),
    StateRec(29, 14, 5, 27, 197),
    StateRec(29, 15, 5, 0, 198),
    StateRec(29, 16, 5, 0, 199),
    StateRec(29, 17, 5, 0, 200),
    StateRec(29, 18, 5, 0, 201),
    StateRec(29, 19, 5, 0, 202),
    StateRec(29, 20, -1, 0, 0),
    StateRec(29, 10, 5, 0, 204),
    StateRec(29, 9, 5, 0, 205),
    StateRec(29, 8, 5, 0, 206),
    StateRec(29, 7, 5, 0, 176),
    StateRec(30, 0, 10, 29, 208),
    StateRec(30, 1, 10, 29, 207),
    StateRec(30, 0, 3, 30, 210),
    StateRec(30, 0, 3, 30, 211),
    StateRec(30, 1, 3, 30, 212),
    StateRec(30, 1, 3, 30, 213),
    StateRec(30, 2, 3, 30, 214),
    StateRec(30, 2, 3, 30, 215),
    StateRec(30, 3, 3, 30, 216),
    StateRec(30, 3, 3, 30, 209),
    StateRec(30, 4, 10, 31, 218),
    StateRec(30, 32773, 10, 34, 219),
    StateRec(30, 4, 10, 0, 209),
    StateRec(30, 6, 3, 0, 221),
    StateRec(30, 6, 3, 25, 209),
    StateRec(30, 7, 5, 0, 223),
    StateRec(30, 8, 5, 33, 224),
    StateRec(30, 9, 5, 27, 225),
    StateRec(30, 10, 5, 0, 226),
    StateRec(30, 11, -1, 0, 0),
    StateRec(30, 12, 5, 0, 228),
    StateRec(30, 13, 5, 28, 229),
    StateRec(30, 14, 5, 27, 230),
    StateRec(30, 15, 5, 0, 231),
    StateRec(30, 16, 5, 0, 232),
    StateRec(30, 17, 5, 0, 233),
    StateRec(30, 18, 5, 0, 234),
    StateRec(30, 19, 5, 0, 235),
    StateRec(30, 20, -1, 0, 0),
    StateRec(30, 11, 5, 0, 237),
    StateRec(30, 10, 5, 0, 238),
    StateRec(30, 9, 5, 0, 239),
    StateRec(30, 8, 5, 0, 240),
    StateRec(30, 7, 5, 0, 209),
    StateRec(31, 0, 10, 29, 242),
    StateRec(31, 1, 10, 29, 241),
    StateRec(31, 0, 2, 35, 244),
    StateRec(31, 0, 2, 35, 245),
    StateRec(31, 1, 2, 35, 246),
    StateRec(31, 1, 2, 35, 247),
    StateRec(31, 2, 2, 35, 248),
    StateRec(31, 2, 2, 35, 249),
    StateRec(31, 3, 2, 35, 250),
    StateRec(31, 3, 2, 35, 251),
    StateRec(31, 4, 2, 35, 252),
    StateRec(31, 4, 2, 35, 253),
    StateRec(31, 5, 2, 35, 254),
    StateRec(31, 5, 2, 35, 243),
    StateRec(31, 32774, 0, 36, 256),
    StateRec(31, 32774, 10, 31, 257),
    StateRec(31, 32775, 8, 37, 258),
    StateRec(31, 32776, 8, 31, 259),
    StateRec(31, 32777, 8, 31, 260),
    StateRec(31, 32778, 8, 31, 261),
    StateRec(31, 32779, 8, 31, 262),
    StateRec(31, 32780, 8, 31, 263),
    StateRec(31, 32781, 8, 31, 264),
    StateRec(31, 32782, 8, 38, 265),
    StateRec(31, 32783, 20, 0, 243),
    StateRec(31, 32794, 10, 0, 267),
    StateRec(31, 32795, 10, 0, 268),
    StateRec(31, 32796, 10, 0, 243),
    StateRec(31, 16, 5, 0, 270),
    StateRec(31, 16, 5, 25, 243),
    StateRec(31, 16, 7, 0, 272),
    StateRec(31, 17, 7, 33, 273),
    StateRec(31, 18, 7, 27, 274),
    StateRec(31, 19, 7, 0, 275),
    StateRec(31, 20, 7, 0, 276),
    StateRec(31, 21, 7, 0, 277),
    StateRec(31, 22, 7, 0, 278),
    StateRec(31, 23, 5, 0, 279),
    StateRec(31, 24, 5, 0, 280),
    StateRec(31, 25, -1, 0, 0),
    StateRec(32, 32768, 2, 39, 282),
    StateRec(32, 32769, 2, 40, 283),
    StateRec(32, 32768, 2, 40, 284),
    StateRec(32, 32769, 2, 40, 285),
    StateRec(32, 32770, 2, 41, 286),
    StateRec(32, 32769, 2, 40, 287),
    StateRec(32, 32770, 2, 40, 288),
    StateRec(32, 32769, 2, 40, 289),
    StateRec(32, 32770, 2, 40, 290),
    StateRec(32, 32771, 2, 40, 291),
    StateRec(32, 32770, 2, 40, 292),
    StateRec(32, 32771, 2, 40, 293),
    StateRec(32, 32770, 2, 40, 294),
    StateRec(32, 32771, 2, 40, 295),
    StateRec(32, 32772, 2, 40, 296),
    StateRec(32, 32771, 2, 40, 297),
    StateRec(32, 32772, 2, 40, 298),
    StateRec(32, 32771, 2, 40, 299),
    StateRec(32, 32772, 2, 41, 300),
    StateRec(32, 32773, 2, 40, 301),
    StateRec(32, 32772, 2, 40, 302),
    StateRec(32, 32773, 2, 40, 303),
    StateRec(32, 32772, 2, 40, 304),
    StateRec(32, 32773, 2, 40, 305),
    StateRec(32, 32774, 2, 40, 306),
    StateRec(32, 32775, 2, 40, 307),
    StateRec(32, 32774, 2, 40, 308),
    StateRec(32, 32775, 2, 40, 309),
    StateRec(32, 32774, 2, 40, 310),
    StateRec(32, 32775, 2, 40, 0),
    StateRec(17, 1, 4, 0, 312),
    StateRec(17, 2, 4, 0, 313),
    StateRec(17, 1, 4, 0, 314),
    StateRec(17, 2, 4, 0, 315),
    StateRec(17, 3, 4, 0, 0),
    StateRec(33, 32768, 2, 42, 317),
    StateRec(33, 32769, 2, 42, 316),
    StateRec(34, 32768, 8, 0, 319),
    StateRec(34, 32769, 6, 0, 320),
    StateRec(34, 32770, 4, 0, 0),
    StateRec(35, 0, 10, 29, 322),
    StateRec(35, 1, 10, 29, 321),
    StateRec(35, 0, 2, 30, 324),
    StateRec(35, 0, 2, 30, 325),
    StateRec(35, 1, 2, 30, 326),
    StateRec(35, 1, 2, 30, 327),
    StateRec(35, 2, 2, 30, 328),
    StateRec(35, 2, 2, 30, 329),
    StateRec(35, 3, 2, 30, 330),
    StateRec(35, 3, 2, 30, 331),
    StateRec(35, 4, 2, 30, 332),
    StateRec(35, 4, 2, 30, 333),
    StateRec(35, 5, 2, 30, 334),
    StateRec(35, 5, 2, 30, 323),
    StateRec(35, 6, 0, 31, 336),
    StateRec(35, 6, 6, 43, 337),
    StateRec(35, 7, 6, 31, 338),
    StateRec(35, 8, 6, 44, 323),
    StateRec(35, 32777, 0, 31, 340),
    StateRec(35, 32777, 10, 31, 341),
    StateRec(35, 10, 10, 45, 342),
    StateRec(35, 10, 10, 31, 323),
    StateRec(35, 11, 5, 0, 344),
    StateRec(35, 11, 5, 25, 323),
    StateRec(35, 11, 7, 0, 346),
    StateRec(35, 12, 7, 0, 347),
    StateRec(35, 13, 7, 33, 348),
    StateRec(35, 14, 7, 27, 349),
    StateRec(35, 15, 7, 0, 350),
    StateRec(35, 16, -1, 0, 0),
    StateRec(35, 16, 5, 0, 352),
    StateRec(35, 15, 5, 0, 353),
    StateRec(35, 14, 5, 0, 354),
    StateRec(35, 13, 5, 0, 355),
    StateRec(35, 12, 5, 0, 356),
    StateRec(35, 11, 5, 0, 323),
    StateRec(36, 32768, 4, 0, 358),
    StateRec(36, 32769, 4, 0, 357),
    StateRec(22, 32769, 8, 0, 360),
    StateRec(22, 32770, 6, 0, 361),
    StateRec(22, 32771, 4, 0, 0),
    StateRec(37, 0, 15, 29, 363),
    StateRec(37, 1, 15, 29, 362),
    StateRec(37, 0, 4, 30, 365),
    StateRec(37, 0, 4, 30, 366),
    StateRec(37, 1, 4, 30, 367),
    StateRec(37, 1, 4, 30, 368),
    StateRec(37, 2, 4, 30, 369),
    StateRec(37, 2, 4, 30, 370),
    StateRec(37, 3, 4, 30, 371),
    StateRec(37, 3, 4, 30, 372),
    StateRec(37, 4, 4, 30, 373),
    StateRec(37, 4, 4, 30, 374),
    StateRec(37, 5, 4, 30, 375),
    StateRec(37, 5, 4, 30, 364),
    StateRec(37, 6, 20, 46, 377),
    StateRec(37, 32775, 10, 47, 378),
    StateRec(37, 8, 5, 31, 379),
    StateRec(37, 6, 5, 31, 380),
    StateRec(37, 32775, 10, 48, 381),
    StateRec(37, 8, 5, 31, 382),
    StateRec(37, 6, 5, 31, 383),
    StateRec(37, 32775, 10, 49, 384),
    StateRec(37, 8, 5, 31, 385),
    StateRec(37, 6, 5, 31, 364),
    StateRec(37, 9, 3, 0, 387),
    StateRec(37, 9, 3, 25, 364),
    StateRec(37, 10, 6, 0, 389),
    StateRec(37, 11, 6, 33, 390),
    StateRec(37, 12, 6, 27, 391),
    StateRec(37, 13, 6, 0, 392),
    StateRec(37, 14, 6, 0, 393),
    StateRec(37, 15, 6, 0, 394),
    StateRec(37, 16, 6, 0, 395),
    StateRec(37, 17, 6, 0, 396),
    StateRec(37, 18, 6, 0, 397),
    StateRec(37, 19, -1, 50, 0),
    StateRec(37, 17, 5, 0, 399),
    StateRec(37, 16, 5, 0, 400),
    StateRec(37, 15, 5, 0, 401),
    StateRec(37, 14, 5, 0, 402),
    StateRec(37, 13, 5, 0, 403),
    StateRec(37, 12, 5, 0, 404),
    StateRec(37, 11, 5, 0, 405),
    StateRec(37, 10, 5, 0, 364),
    StateRec(38, 0, 10, 29, 407),
    StateRec(38, 1, 10, 29, 406),
    StateRec(38, 0, 3, 30, 409),
    StateRec(38, 0, 3, 30, 410),
    StateRec(38, 1, 3, 30, 411),
    StateRec(38, 1, 3, 30, 412),
    StateRec(38, 2, 3, 30, 413),
    StateRec(38, 2, 3, 30, 414),
    StateRec(38, 3, 3, 30, 415),
    StateRec(38, 3, 3, 30, 408),
    StateRec(38, 4, 10, 31, 417),
    StateRec(38, 32773, 4, 51, 418),
    StateRec(38, 32772, 4, 51, 419),
    StateRec(38, 5, 1, 52, 417),
    StateRec(38, 6, 3, 0, 421),
    StateRec(38, 6, 3, 25, 408),
    StateRec(38, 7, 5, 0, 423),
    StateRec(38, 8, 5, 33, 424),
    StateRec(38, 9, 5, 27, 425),
    StateRec(38, 10, 5, 0, 426),
    StateRec(38, 11, 5, 0, 427),
    StateRec(38, 12, 5, 0, 428),
    StateRec(38, 13, -1, 0, 0),
    StateRec(38, 14, 5, 0, 430),
    StateRec(38, 15, 5, 28, 431),
    StateRec(38, 16, 5, 27, 432),
    StateRec(38, 17, 5, 0, 433),
    StateRec(38, 18, 5, 0, 434),
    StateRec(38, 19, -1, 0, 0),
    StateRec(38, 13, 5, 0, 436),
    StateRec(38, 12, 5, 0, 437),
    StateRec(38, 11, 5, 0, 438),
    StateRec(38, 10, 5, 0, 439),
    StateRec(38, 9, 5, 0, 440),
    StateRec(38, 8, 5, 0, 441),
    StateRec(38, 7, 5, 0, 408),
    StateRec(0, 0, 10, 29, 443),
    StateRec(0, 1, 10, 29, 442),
    StateRec(0, 0, 3, 30, 445),
    StateRec(0, 0, 3, 30, 446),
    StateRec(0, 1, 3, 30, 447),
    StateRec(0, 1, 3, 30, 448),
    StateRec(0, 2, 3, 30, 449),
    StateRec(0, 2, 3, 30, 450),
    StateRec(0, 3, 3, 30, 451),
    StateRec(0, 3, 3, 30, 444),
    StateRec(0, 4, 8, 31, 453),
    StateRec(0, 5, 8, 31, 454),
    StateRec(0, 6, 6, 53, 444),
    StateRec(0, 7, 2, 0, 456),
    StateRec(0, 7, 2, 25, 444),
    StateRec(0, 8, 8, 0, 458),
    StateRec(0, 9, 8, 33, 459),
    StateRec(0, 10, 6, 0, 460),
    StateRec(0, 11, 6, 27, 461),
    StateRec(0, 12, -1, 0, 0),
    StateRec(0, 13, 5, 0, 463),
    StateRec(0, 14, 5, 28, 464),
    StateRec(0, 15, 5, 0, 465),
    StateRec(0, 16, 5, 27, 466),
    StateRec(0, 17, 5, 0, 467),
    StateRec(0, 18, 5, 0, 468),
    StateRec(0, 19, 5, 0, 469),
    StateRec(0, 20, -1, 0, 0),
    StateRec(0, 12, 8, 0, 471),
    StateRec(0, 11, 8, 0, 472),
    StateRec(0, 10, 6, 0, 473),
    StateRec(0, 9, 6, 0, 474),
    StateRec(0, 8, 6, 0, 444),
    StateRec(39, 0, 10, 29, 476),
    StateRec(39, 1, 10, 29, 475),
    StateRec(39, 0, 2, 30, 478),
    StateRec(39, 0, 2, 30, 479),
    StateRec(39, 1, 2, 30, 480),
    StateRec(39, 1, 2, 30, 481),
    StateRec(39, 2, 2, 30, 482),
    StateRec(39, 2, 2, 30, 483),
    StateRec(39, 3, 2, 30, 484),
    StateRec(39, 3, 2, 30, 477),
    StateRec(39, 4, 8, 31, 486),
    StateRec(39, 5, 8, 31, 487),
    StateRec(39, 6, 8, 54, 477),
    StateRec(39, 7, 2, 0, 489),
    StateRec(39, 7, 2, 25, 477),
    StateRec(39, 8, 8, 0, 491),
    StateRec(39, 9, 8, 33, 492),
    StateRec(39, 10, 4, 0, 493),
    StateRec(39, 11, 4, 27, 494),
    StateRec(39, 12, 4, 0, 495),
    StateRec(39, 13, -1, 0, 0),
    StateRec(39, 13, 5, 0, 497),
    StateRec(39, 12, 5, 0, 498),
    StateRec(39, 11, 5, 0, 499),
    StateRec(39, 10, 5, 0, 500),
    StateRec(39, 9, 5, 0, 501),
    StateRec(39, 8, 5, 0, 477),
    StateRec(40, 0, 10, 29, 502),
    StateRec(40, 0, 3, 30, 503),
    StateRec(40, 1, 5, 31, 505),
    StateRec(40, 2, 5, 31, 506),
    StateRec(40, 32771, 5, 55, 503),
    StateRec(40, 4, 3, 0, 508),
    StateRec(40, 4, 3, 25, 509),
    StateRec(40, 5, 6, 0, 503),
    StateRec(40, 6, 8, 0, 511),
    StateRec(40, 7, 8, 33, 512),
    StateRec(40, 8, 8, 0, 513),
    StateRec(40, 9, 8, 0, 514),
    StateRec(40, 10, 8, 27, 515),
    StateRec(40, 11, -1, 0, 0),
    StateRec(40, 11, 8, 0, 517),
    StateRec(40, 10, 8, 0, 518),
    StateRec(40, 9, 8, 0, 519),
    StateRec(40, 8, 8, 0, 520),
    StateRec(40, 7, 8, 0, 521),
    StateRec(40, 6, 8, 0, 503),
    StateRec(41, 32768, 4, 0, 523),
    StateRec(41, 32769, 4, 0, 522),
    StateRec(41, 32770, 6, 0, 525),
    StateRec(41, 32771, 6, 0, 526),
    StateRec(41, 32772, 6, 0, 0),
    StateRec(42, 0, 10, 29, 528),
    StateRec(42, 1, 10, 29, 527),
    StateRec(42, 0, 3, 30, 530),
    StateRec(42, 0, 3, 30, 531),
    StateRec(42, 1, 3, 30, 532),
    StateRec(42, 1, 3, 30, 533),
    StateRec(42, 2, 3, 30, 534),
    StateRec(42, 2, 3, 30, 535),
    StateRec(42, 3, 3, 30, 536),
    StateRec(42, 3, 3, 30, 529),
    StateRec(42, 4, 8, 31, 538),
    StateRec(42, 5, 8, 31, 539),
    StateRec(42, 6, 8, 56, 529),
    StateRec(42, 7, 2, 0, 541),
    StateRec(42, 7, 2, 25, 529),
    StateRec(42, 8, 8, 0, 543),
    StateRec(42, 9, 8, 33, 544),
    StateRec(42, 10, 8, 0, 545),
    StateRec(42, 11, 8, 27, 546),
    StateRec(42, 12, 8, 0, 547),
    StateRec(42, 13, 8, 0, 548),
    StateRec(42, 14, -1, 50, 0),
    StateRec(42, 14, 8, 0, 550),
    StateRec(42, 13, 8, 0, 551),
    StateRec(42, 12, 8, 0, 552),
    StateRec(42, 11, 8, 0, 553),
    StateRec(42, 10, 8, 0, 554),
    StateRec(42, 9, 8, 0, 555),
    StateRec(42, 8, 8, 0, 529),
    StateRec(43, 0, 10, 29, 557),
    StateRec(43, 1, 10, 29, 556),
    StateRec(43, 0, 3, 30, 559),
    StateRec(43, 0, 3, 30, 560),
    StateRec(43, 1, 3, 30, 561),
    StateRec(43, 1, 3, 30, 562),
    StateRec(43, 2, 3, 30, 563),
    StateRec(43, 2, 3, 30, 564),
    StateRec(43, 3, 3, 30, 565),
    StateRec(43, 3, 3, 30, 558),
    StateRec(43, 4, 8, 31, 567),
    StateRec(43, 5, 8, 31, 568),
    StateRec(43, 6, 8, 56, 558),
    StateRec(43, 7, 2, 0, 570),
    StateRec(43, 7, 2, 25, 558),
    StateRec(43, 8, 8, 0, 572),
    StateRec(43, 9, 8, 33, 573),
    StateRec(43, 10, 8, 0, 574),
    StateRec(43, 11, 8, 27, 575),
    StateRec(43, 12, 8, 0, 576),
    StateRec(43, 13, 8, 0, 577),
    StateRec(43, 14, -1, 0, 0),
    StateRec(43, 14, 8, 0, 579),
    StateRec(43, 13, 8, 0, 580),
    StateRec(43, 12, 8, 0, 581),
    StateRec(43, 11, 8, 0, 582),
    StateRec(43, 10, 8, 0, 583),
    StateRec(43, 9, 8, 0, 584),
    StateRec(43, 8, 8, 0, 558),
    StateRec(44, 32768, 10, 29, 586),
    StateRec(44, 32769, 10, 29, 585),
    StateRec(44, 32768, 6, 30, 588),
    StateRec(44, 32769, 6, 30, 587),
    StateRec(44, 32770, 10, 31, 590),
    StateRec(44, 32771, 4, 57, 591),
    StateRec(44, 32770, 4, 0, 592),
    StateRec(44, 32771, 4, 0, 591),
    StateRec(44, 32772, 3, 0, 594),
    StateRec(44, 32772, 3, 25, 587),
    StateRec(44, 32773, 6, 0, 596),
    StateRec(44, 32774, 6, 33, 597),
    StateRec(44, 32775, 6, 0, 598),
    StateRec(44, 32776, 6, 27, 599),
    StateRec(44, 9, 6, 0, 600),
    StateRec(44, 10, 6, 0, 0),
    StateRec(45, 0, 10, 29, 602),
    StateRec(45, 1, 10, 29, 601),
    StateRec(45, 0, 3, 58, 604),
    StateRec(45, 0, 3, 30, 605),
    StateRec(45, 1, 3, 30, 606),
    StateRec(45, 1, 3, 30, 607),
    StateRec(45, 2, 3, 58, 608),
    StateRec(45, 2, 3, 30, 609),
    StateRec(45, 3, 3, 30, 610),
    StateRec(45, 3, 3, 30, 611),
    StateRec(45, 4, 3, 58, 612),
    StateRec(45, 4, 3, 30, 613),
    StateRec(45, 5, 3, 30, 614),
    StateRec(45, 5, 3, 30, 603),
    StateRec(45, 32768, 20, 31, 616),
    StateRec(45, 32774, 4, 34, 617),
    StateRec(45, 32775, 4, 34, 618),
    StateRec(45, 32775, 1, 59, 616),
    StateRec(45, 8, 3, 0, 620),
    StateRec(45, 8, 3, 25, 603),
    StateRec(45, 9, 20, 33, 622),
    StateRec(45, 10, 10, 27, 623),
    StateRec(45, 11, 10, 0, 624),
    StateRec(45, 12, 10, 0, 625),
    StateRec(45, 13, 10, 0, 626),
    StateRec(45, 14, 10, 0, 627),
    StateRec(45, 15, 10, 0, 628),
    StateRec(45, 16, 10, 0, 629),
    StateRec(45, 17, 10, 0, 630),
    StateRec(45, 18, 30, 0, 631),
    StateRec(45, 18, -1, 50, 0),
    StateRec(46, 0, 10, 29, 633),
    StateRec(46, 1, 10, 29, 632),
    StateRec(46, 0, 20, 0, 635),
    StateRec(46, 0, 3, 60, 636),
    StateRec(46, 0, 3, 30, 637),
    StateRec(46, 1, 3, 30, 638),
    StateRec(46, 1, 3, 30, 639),
    StateRec(46, 2, 3, 30, 640),
    StateRec(46, 2, 3, 30, 641),
    StateRec(46, 3, 3, 60, 642),
    StateRec(46, 3, 3, 30, 643),
    StateRec(46, 4, 3, 30, 644),
    StateRec(46, 4, 3, 30, 645),
    StateRec(46, 5, 3, 30, 646),
    StateRec(46, 5, 3, 30, 635),
    StateRec(46, 32768, 20, 31, 648),
    StateRec(46, 32774, 4, 61, 649),
    StateRec(46, 32775, 4, 0, 650),
    StateRec(46, 32775, 1, 59, 648),
    StateRec(46, 8, 3, 0, 652),
    StateRec(46, 8, 3, 25, 635),
    StateRec(46, 9, 20, 33, 654),
    StateRec(46, 10, 7, 27, 655),
    StateRec(46, 11, 7, 0, 656),
    StateRec(46, 12, 7, 0, 657),
    StateRec(46, 13, 7, 0, 658),
    StateRec(46, 14, 7, 0, 659),
    StateRec(46, 15, -1, 50, 0),
    StateRec(46, 15, 5, 0, 661),
    StateRec(46, 14, 5, 0, 662),
    StateRec(46, 13, 5, 0, 663),
    StateRec(46, 12, 5, 0, 664),
    StateRec(46, 11, 5, 0, 665),
    StateRec(46, 10, 5, 0, 666),
    StateRec(46, 9, 5, 0, 635),
    StateRec(47, 32768, 5, 0, 668),
    StateRec(47, 32769, 5, 0, 667),
    StateRec(48, 32768, 5, 0, 670),
    StateRec(48, 32769, 5, 0, 671),
    StateRec(48, 32770, 5, 0, 672),
    StateRec(48, 32771, 5, 0, 673),
    StateRec(48, 32772, 5, 0, 0),
    StateRec(49, 0, 10, 29, 675),
    StateRec(49, 1, 10, 29, 674),
    StateRec(49, 0, 3, 62, 677),
    StateRec(49, 0, 3, 30, 678),
    StateRec(49, 1, 3, 30, 679),
    StateRec(49, 1, 3, 30, 680),
    StateRec(49, 2, 3, 30, 681),
    StateRec(49, 2, 3, 30, 682),
    StateRec(49, 3, 3, 58, 683),
    StateRec(49, 3, 3, 30, 676),
    StateRec(49, 4, 6, 31, 685),
    StateRec(49, 5, 12, 63, 686),
    StateRec(49, 4, 12, 31, 687),
    StateRec(49, 5, 12, 63, 688),
    StateRec(49, 4, 12, 31, 689),
    StateRec(49, 5, 12, 63, 676),
    StateRec(49, 6, 10, 25, 676),
    StateRec(49, 7, 10, 0, 692),
    StateRec(49, 8, 10, 33, 693),
    StateRec(49, 9, 10, 0, 694),
    StateRec(49, 10, 10, 0, 695),
    StateRec(49, 11, 10, 0, 696),
    StateRec(49, 12, 10, 27, 697),
    StateRec(49, 13, 10, 0, 698),
    StateRec(49, 14, 10, 0, 699),
    StateRec(49, 15, 30, 0, 700),
    StateRec(49, 15, -1, 50, 0),
    StateRec(50, 0, 10, 29, 701),
    StateRec(50, 0, 3, 30, 703),
    StateRec(50, 0, 3, 30, 704),
    StateRec(50, 1, 3, 30, 705),
    StateRec(50, 1, 3, 30, 706),
    StateRec(50, 2, 3, 30, 707),
    StateRec(50, 2, 3, 30, 702),
    StateRec(50, 3, 5, 31, 709),
    StateRec(50, 4, 5, 31, 710),
    StateRec(50, 32773, 5, 31, 711),
    StateRec(50, 32773, 0, 64, 702),
    StateRec(50, 6, 6, 0, 713),
    StateRec(50, 6, 6, 25, 702),
    StateRec(50, 32775, 8, 0, 715),
    StateRec(50, 32776, 8, 33, 716),
    StateRec(50, 32777, 8, 0, 717),
    StateRec(50, 32778, 8, 0, 718),
    StateRec(50, 32779, 8, 65, 719),
    StateRec(50, 32780, 8, 0, 0),
    StateRec(50, 12, 8, 0, 721),
    StateRec(50, 11, 8, 0, 722),
    StateRec(50, 10, 8, 0, 723),
    StateRec(50, 9, 8, 0, 724),
    StateRec(50, 8, 8, 0, 725),
    StateRec(50, 7, 8, 0, 702),
    StateRec(51, 0, 10, 29, 727),
    StateRec(51, 1, 10, 29, 726),
    StateRec(51, 0, 3, 30, 729),
    StateRec(51, 0, 3, 30, 730),
    StateRec(51, 1, 3, 30, 731),
    StateRec(51, 1, 3, 30, 732),
    StateRec(51, 2, 3, 30, 733),
    StateRec(51, 2, 3, 30, 734),
    StateRec(51, 3, 3, 30, 735),
    StateRec(51, 3, 3, 30, 728),
    StateRec(51, 4, 10, 31, 737),
    StateRec(51, 5, 10, 31, 738),
    StateRec(51, 32774, 4, 51, 739),
    StateRec(51, 5, 6, 31, 740),
    StateRec(51, 32774, 4, 51, 741),
    StateRec(51, 5, 1, 52, 737),
    StateRec(51, 7, 3, 0, 743),
    StateRec(51, 7, 3, 25, 728),
    StateRec(51, 8, 5, 0, 745),
    StateRec(51, 9, 5, 33, 746),
    StateRec(51, 10, 5, 27, 747),
    StateRec(51, 11, 5, 0, 748),
    StateRec(51, 12, -1, 0, 0),
    StateRec(51, 13, 5, 0, 750),
    StateRec(51, 14, 5, 28, 751),
    StateRec(51, 15, 5, 27, 752),
    StateRec(51, 16, 5, 0, 753),
    StateRec(51, 17, 5, 0, 754),
    StateRec(51, 18, 5, 0, 755),
    StateRec(51, 19, 5, 0, 756),
    StateRec(51, 20, 5, 0, 757),
    StateRec(51, 21, -1, 0, 0),
    StateRec(51, 12, 5, 0, 759),
    StateRec(51, 11, 5, 0, 760),
    StateRec(51, 10, 5, 0, 761),
    StateRec(51, 9, 5, 0, 762),
    StateRec(51, 8, 5, 0, 728),
    StateRec(52, 0, -1, 0, 763),
    StateRec(52, 0, 6, 0, 765),
    StateRec(52, 1, 6, 0, 766),
    StateRec(52, 2, 6, 33, 767),
    StateRec(52, 3, 6, 0, 768),
    StateRec(52, 4, 6, 0, 769),
    StateRec(52, 5, 6, 0, 770),
    StateRec(52, 6, 6, 0, 771),
    StateRec(52, 7, 6, 0, 772),
    StateRec(52, 8, 6, 0, 773),
    StateRec(52, 9, 6, 0, 774),
    StateRec(52, 10, 6, 66, 775),
    StateRec(52, 11, -1, 0, 0),
    StateRec(52, 12, 4, 0, 777),
    StateRec(52, 12, 8, 25, 763),
    StateRec(53, 0, -1, 0, 0),
    StateRec(53, 1, 36, 67, 778),
    StateRec(53, 0, 100, 68, 781),
    StateRec(53, 0, 10, 0, 782),
    StateRec(53, 0, 10, 0, 783),
    StateRec(53, 0, -1, 69, 0),
    StateRec(51, 0, 10, 29, 784),
    StateRec(51, 0, 181, 70, 786),
    StateRec(51, 0, 150, 71, 786),
    StateRec(54, 32768, 3, 72, 788),
    StateRec(54, 32769, 3, 73, 789),
    StateRec(54, 32770, 3, 73, 790),
    StateRec(54, 32771, 3, 73, 787),
    StateRec(32, 32768, 4, 40, 792),
    StateRec(32, 32769, 4, 40, 793),
    StateRec(32, 32770, 4, 40, 794),
    StateRec(32, 32771, 4, 40, 795),
    StateRec(32, 32772, 4, 40, 796),
    StateRec(32, 32773, 4, 40, 797),
    StateRec(32, 32774, 4, 40, 798),
    StateRec(32, 32775, 4, 40, 0),
    StateRec(22, 32769, 10, 0, 800),
    StateRec(22, 32770, 10, 0, 801),
    StateRec(22, 32771, 10, 74, 0),
    StateRec(55, 0, 6, 0, 803),
    StateRec(55, 32769, 7, 0, 802),
    StateRec(56, 0, 6, 0, 805),
    StateRec(56, 32769, 6, 0, 804),
    StateRec(57, 0, 6, 0, 807),
    StateRec(57, 1, 6, 0, 806),
    StateRec(58, 32768, 5, 0, 809),
    StateRec(58, 32769, 5, 33, 810),
    StateRec(58, 32770, 5, 0, 811),
    StateRec(58, 32771, 10, 24, 812),
    StateRec(58, 32772, 10, 0, 0),
    StateRec(59, 32768, 4, 0, 814),
    StateRec(59, 32769, 4, 0, 815),
    StateRec(59, 32770, 4, 0, 813),
    StateRec(60, 0, 6, 0, 817),
    StateRec(60, 1, 6, 0, 818),
    StateRec(60, 2, 6, 0, 819),
    StateRec(60, 3, 6, 0, 820),
    StateRec(60, 2, 6, 0, 821),
    StateRec(60, 1, 6, 0, 816),
    StateRec(61, 0, 6, 0, 823),
    StateRec(61, 1, 6, 0, 824),
    StateRec(61, 2, 6, 0, 825),
    StateRec(61, 3, 6, 0, 826),
    StateRec(61, 2, 6, 0, 827),
    StateRec(61, 1, 6, 0, 822),
    StateRec(62, 0, 10, 0, 829),
    StateRec(62, 32769, 10, 0, 828),
    StateRec(63, 0, 10, 0, 831),
    StateRec(63, 32769, 10, 0, 830),
    StateRec(64, 0, 10, 0, 833),
    StateRec(64, 32769, 10, 0, 832),
    StateRec(65, 0, 10, 0, 835),
    StateRec(65, 32769, 10, 0, 834),
    StateRec(66, 0, 10, 0, 837),
    StateRec(66, 32769, 10, 0, 836),
    StateRec(67, 0, 10, 0, 839),
    StateRec(67, 32769, 10, 0, 838),
    StateRec(68, 0, -1, 0, 0),
    StateRec(69, 0, -1, 0, 0),
    StateRec(70, 32768, 6, 0, 843),
    StateRec(70, 32769, 6, 0, 844),
    StateRec(70, 32770, 6, 0, 845),
    StateRec(70, 32771, 6, 0, 846),
    StateRec(70, 32770, 6, 0, 847),
    StateRec(70, 32769, 6, 0, 842),
    StateRec(71, 32768, 6, 0, 849),
    StateRec(71, 32769, 6, 0, 850),
    StateRec(71, 32770, 6, 0, 851),
    StateRec(71, 32771, 6, 0, 848),
    StateRec(72, 32768, -1, 0, 0),
    StateRec(73, 32768, 6, 0, 854),
    StateRec(73, 32769, 6, 0, 855),
    StateRec(73, 32770, 6, 0, 856),
    StateRec(73, 32771, 6, 0, 853),
    StateRec(74, 32768, 6, 0, 858),
    StateRec(74, 32769, 6, 0, 859),
    StateRec(74, 32770, 6, 0, 860),
    StateRec(74, 32771, 6, 0, 857),
    StateRec(75, 32768, -1, 0, 0),
    StateRec(76, 32768, 6, 0, 863),
    StateRec(76, 32769, 6, 0, 864),
    StateRec(76, 32770, 6, 0, 865),
    StateRec(76, 32771, 6, 0, 866),
    StateRec(76, 32770, 6, 0, 867),
    StateRec(76, 32769, 6, 0, 862),
    StateRec(77, 32768, 6, 0, 869),
    StateRec(77, 1, 6, 0, 868),
    StateRec(78, 0, -1, 0, 0),
    StateRec(79, 0, -1, 0, 0),
    StateRec(80, 0, -1, 0, 0),
    StateRec(81, 0, -1, 0, 0),
    StateRec(82, 0, -1, 0, 0),
    StateRec(83, 0, -1, 0, 0),
    StateRec(84, 0, -1, 0, 0),
    StateRec(85, 0, -1, 0, 0),
    StateRec(86, 0, -1, 0, 0),
    StateRec(87, 0, -1, 0, 0),
    StateRec(88, 0, -1, 0, 0),
    StateRec(89, 0, -1, 0, 0),
    StateRec(90, 0, -1, 0, 0),
    StateRec(91, 0, -1, 0, 0),
    StateRec(92, 0, -1, 0, 0),
    StateRec(93, 0, -1, 0, 0),
    StateRec(94, 32768, -1, 0, 0),
    StateRec(95, 0, -1, 0, 0),
    StateRec(96, 0, 10, 0, 889),
    StateRec(96, 1, 15, 0, 890),
    StateRec(96, 2, 8, 0, 891),
    StateRec(96, 1, 6, 0, 888),
    StateRec(28, 13, -1, 0, 0),
    StateRec(28, 18, -1, 0, 0),
    StateRec(97, 0, -1, 0, 0),
    StateRec(98, 0, -1, 0, 0),
    StateRec(99, 0, -1, 0, 0),
    StateRec(100, 32768, 6, 0, 898),
    StateRec(100, 32769, 6, 0, 897),
    StateRec(101, 0, -1, 0, 0),
    StateRec(102, 0, 6, 0, 901),
    StateRec(102, 1, 8, 0, 900),
    StateRec(103, 0, -1, 0, 0),
    StateRec(104, 0, -1, 0, 0),
    StateRec(105, 0, -1, 0, 0),
    StateRec(106, 0, -1, 0, 0),
    StateRec(107, 0, -1, 0, 0),
    StateRec(108, 0, -1, 0, 0),
    StateRec(109, 0, -1, 0, 0),
    StateRec(110, 0, -1, 0, 0),
    StateRec(111, 0, -1, 0, 0),
    StateRec(112, 32768, -1, 0, 0),
    StateRec(113, 32768, -1, 0, 0),
    StateRec(114, 0, -1, 0, 0),
    StateRec(115, 0, -1, 0, 0),
    StateRec(116, 0, -1, 0, 0),
    StateRec(117, 0, -1, 0, 0),
    StateRec(118, 32768, 6, 0, 918),
    StateRec(118, 32769, 6, 0, 919),
    StateRec(118, 32770, 6, 0, 920),
    StateRec(118, 32769, 6, 0, 917),
    StateRec(119, 32768, 6, 0, 922),
    StateRec(119, 32769, 6, 0, 923),
    StateRec(119, 32770, 6, 0, 921),
    StateRec(120, 0, 14, 0, 925),
    StateRec(120, 1, 14, 0, 924),
    StateRec(121, 32768, 4, 0, 927),
    StateRec(121, 32769, 4, 0, 928),
    StateRec(121, 32770, 4, 0, 929),
    StateRec(121, 32771, 4, 0, 926),
    StateRec(122, 32768, 4, 0, 931),
    StateRec(122, 32769, 4, 0, 932),
    StateRec(122, 32770, 4, 0, 933),
    StateRec(122, 32771, 4, 0, 930),
    StateRec(123, 32768, 4, 0, 935),
    StateRec(123, 32769, 4, 0, 936),
    StateRec(123, 32770, 4, 0, 937),
    StateRec(123, 32771, 4, 0, 934),
    StateRec(124, 32768, 4, 0, 939),
    StateRec(124, 32769, 4, 0, 940),
    StateRec(124, 32770, 4, 0, 941),
    StateRec(124, 32771, 4, 0, 938),
    StateRec(125, 32768, 4, 0, 943),
    StateRec(125, 32769, 4, 0, 944),
    StateRec(125, 32770, 4, 0, 945),
    StateRec(125, 32771, 4, 0, 942),
    StateRec(126, 32768, 4, 0, 947),
    StateRec(126, 32769, 4, 0, 948),
    StateRec(126, 32770, 4, 0, 949),
    StateRec(126, 32771, 4, 0, 946),
    StateRec(127, 0, -1, 0, 0),
    StateRec(128, 0, -1, 0, 0),
    StateRec(129, 0, -1, 0, 0),
    StateRec(130, 0, -1, 0, 0),
    StateRec(131, 0, -1, 0, 0),
    StateRec(132, 0, -1, 0, 0),
    StateRec(133, 0, -1, 0, 0),
    StateRec(134, 0, -1, 0, 0),
    StateRec(135, 0, -1, 0, 0),
    StateRec(136, 32768, 4, 0, 960),
    StateRec(136, 32769, 4, 0, 961),
    StateRec(136, 32770, 4, 0, 962),
    StateRec(136, 32771, 4, 0, 959),
    StateRec(137, 32768, 4, 0, 964),
    StateRec(137, 32769, 4, 0, 965),
    StateRec(137, 32770, 4, 0, 966),
    StateRec(137, 32771, 4, 0, 963),
]
mutable struct MobjInfo
    doomednum::Int
    spawnstate::Int
    spawnhealth::Int
    seestate::Int
    seesound::String
    reactiontime::Int
    attacksound::String
    painstate::Int
    painchance::Int
    painsound::String
    meleestate::Int
    missilestate::Int
    deathstate::Int
    xdeathstate::Int
    deathsound::String
    speed::Int
    radius::Int
    height::Int
    mass::Int
    damage::Int
    activesound::String
    flags::Int
    raisestate::Int
end
const MOBJINFO = MobjInfo[
    MobjInfo(-1, 149, 100, 150, "", 0, "", 156, 255, "plpain", 0, 154, 158, 165, "pldeth", 0, 1048576, 3670016, 100, 0, "", 33557510, 0),
    MobjInfo(3004, 174, 20, 176, "posit1", 8, "pistol", 187, 200, "popain", 0, 184, 189, 194, "podth1", 8, 1310720, 3670016, 100, 0, "posact", 4194310, 203),
    MobjInfo(9, 207, 30, 209, "posit2", 8, "", 220, 170, "popain", 0, 217, 222, 227, "podth2", 8, 1310720, 3670016, 100, 0, "posact", 4194310, 236),
    MobjInfo(64, 241, 700, 243, "vilsit", 8, "", 269, 10, "vipain", 0, 255, 271, 0, "vildth", 15, 1310720, 3670016, 500, 0, "vilact", 4194310, 0),
    MobjInfo(-1, 281, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 528, 0),
    MobjInfo(66, 321, 300, 323, "skesit", 8, "", 343, 100, "popain", 335, 339, 345, 0, "skedth", 10, 1310720, 3670016, 500, 0, "skeact", 4194310, 351),
    MobjInfo(-1, 316, 1000, 0, "skeatk", 8, "", 0, 0, "", 0, 0, 318, 0, "barexp", 655360, 720896, 524288, 100, 10, "", 67088, 0),
    MobjInfo(-1, 311, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 528, 0),
    MobjInfo(67, 362, 600, 364, "mansit", 8, "", 386, 80, "mnpain", 0, 376, 388, 0, "mandth", 8, 3145728, 4194304, 1000, 0, "posact", 4194310, 398),
    MobjInfo(-1, 357, 1000, 0, "firsht", 8, "", 0, 0, "", 0, 0, 359, 0, "firxpl", 1310720, 393216, 524288, 100, 8, "", 67088, 0),
    MobjInfo(65, 406, 70, 408, "posit2", 8, "", 420, 170, "popain", 0, 416, 422, 429, "podth2", 8, 1310720, 3670016, 100, 0, "posact", 4194310, 435),
    MobjInfo(3001, 442, 60, 444, "bgsit1", 8, "", 455, 200, "popain", 452, 452, 457, 462, "bgdth1", 8, 1310720, 3670016, 100, 0, "bgact", 4194310, 470),
    MobjInfo(3002, 475, 150, 477, "sgtsit", 8, "sgtatk", 488, 180, "dmpain", 485, 0, 490, 0, "sgtdth", 10, 1966080, 3670016, 400, 0, "dmact", 4194310, 496),
    MobjInfo(58, 475, 150, 477, "sgtsit", 8, "sgtatk", 488, 180, "dmpain", 485, 0, 490, 0, "sgtdth", 10, 1966080, 3670016, 400, 0, "dmact", 4456454, 496),
    MobjInfo(3005, 502, 400, 503, "cacsit", 8, "", 507, 128, "dmpain", 0, 504, 510, 0, "cacdth", 8, 2031616, 3670016, 400, 0, "dmact", 4211206, 516),
    MobjInfo(3003, 527, 1000, 529, "brssit", 8, "", 540, 50, "dmpain", 537, 537, 542, 0, "brsdth", 8, 1572864, 4194304, 1000, 0, "dmact", 4194310, 549),
    MobjInfo(-1, 522, 1000, 0, "firsht", 8, "", 0, 0, "", 0, 0, 524, 0, "firxpl", 983040, 393216, 524288, 100, 8, "", 67088, 0),
    MobjInfo(69, 556, 500, 558, "kntsit", 8, "", 569, 50, "dmpain", 566, 566, 571, 0, "kntdth", 8, 1572864, 4194304, 1000, 0, "dmact", 4194310, 578),
    MobjInfo(3006, 585, 100, 587, "", 8, "sklatk", 593, 256, "dmpain", 0, 589, 595, 0, "firxpl", 8, 1048576, 3670016, 50, 3, "dmact", 16902, 0),
    MobjInfo(7, 601, 3000, 603, "spisit", 8, "shotgn", 619, 40, "dmpain", 0, 615, 621, 0, "spidth", 12, 8388608, 6553600, 1000, 0, "dmact", 4194310, 0),
    MobjInfo(68, 632, 500, 634, "bspsit", 8, "", 651, 128, "dmpain", 0, 647, 653, 0, "bspdth", 12, 4194304, 4194304, 600, 0, "bspact", 4194310, 660),
    MobjInfo(16, 674, 4000, 676, "cybsit", 8, "", 690, 20, "dmpain", 0, 684, 691, 0, "cybdth", 16, 2621440, 7208960, 1000, 0, "dmact", 4194310, 0),
    MobjInfo(71, 701, 400, 702, "pesit", 8, "", 712, 128, "pepain", 0, 708, 714, 0, "pedth", 8, 2031616, 3670016, 400, 0, "dmact", 4211206, 720),
    MobjInfo(84, 726, 50, 728, "sssit", 8, "", 742, 170, "popain", 0, 736, 744, 749, "ssdth", 8, 1310720, 3670016, 100, 0, "posact", 4194310, 758),
    MobjInfo(72, 763, 100, 0, "", 8, "", 776, 256, "keenpn", 0, 0, 764, 0, "keendt", 0, 1048576, 4718592, 10000000, 0, "", 4195078, 0),
    MobjInfo(88, 778, 250, 0, "", 8, "", 779, 255, "bospn", 0, 0, 780, 0, "bosdth", 0, 1048576, 1048576, 10000000, 0, "", 6, 0),
    MobjInfo(89, 784, 1000, 785, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 2097152, 100, 0, "", 24, 0),
    MobjInfo(87, 0, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 2097152, 100, 0, "", 24, 0),
    MobjInfo(-1, 787, 1000, 0, "bospit", 8, "", 0, 0, "", 0, 0, 0, 0, "firxpl", 655360, 393216, 2097152, 100, 3, "", 71184, 0),
    MobjInfo(-1, 791, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 528, 0),
    MobjInfo(2035, 806, 20, 0, "", 8, "", 0, 0, "", 0, 0, 808, 0, "barexp", 0, 655360, 2752512, 100, 0, "", 524294, 0),
    MobjInfo(-1, 97, 1000, 0, "firsht", 8, "", 0, 0, "", 0, 0, 99, 0, "firxpl", 655360, 393216, 524288, 100, 3, "", 67088, 0),
    MobjInfo(-1, 102, 1000, 0, "firsht", 8, "", 0, 0, "", 0, 0, 104, 0, "firxpl", 655360, 393216, 524288, 100, 5, "", 67088, 0),
    MobjInfo(-1, 114, 1000, 0, "rlaunc", 8, "", 0, 0, "", 0, 0, 127, 0, "barexp", 1310720, 720896, 524288, 100, 20, "", 67088, 0),
    MobjInfo(-1, 107, 1000, 0, "plasma", 8, "", 0, 0, "", 0, 0, 109, 0, "firxpl", 1638400, 851968, 524288, 100, 5, "", 67088, 0),
    MobjInfo(-1, 115, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 117, 0, "rxplod", 1638400, 851968, 524288, 100, 100, "", 67088, 0),
    MobjInfo(-1, 667, 1000, 0, "plasma", 8, "", 0, 0, "", 0, 0, 669, 0, "firxpl", 1638400, 851968, 524288, 100, 5, "", 67088, 0),
    MobjInfo(-1, 93, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 528, 0),
    MobjInfo(-1, 90, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 16, 0),
    MobjInfo(-1, 130, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 528, 0),
    MobjInfo(-1, 142, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 528, 0),
    MobjInfo(14, 0, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 24, 0),
    MobjInfo(-1, 123, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 528, 0),
    MobjInfo(2018, 802, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 1, 0),
    MobjInfo(2019, 804, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 1, 0),
    MobjInfo(2014, 816, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 8388609, 0),
    MobjInfo(2015, 822, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 8388609, 0),
    MobjInfo(5, 828, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 33554433, 0),
    MobjInfo(13, 830, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 33554433, 0),
    MobjInfo(6, 832, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 33554433, 0),
    MobjInfo(39, 838, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 33554433, 0),
    MobjInfo(38, 836, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 33554433, 0),
    MobjInfo(40, 834, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 33554433, 0),
    MobjInfo(2011, 840, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 1, 0),
    MobjInfo(2012, 841, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 1, 0),
    MobjInfo(2013, 842, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 8388609, 0),
    MobjInfo(2022, 848, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 8388609, 0),
    MobjInfo(2023, 852, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 8388609, 0),
    MobjInfo(2024, 853, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 8388609, 0),
    MobjInfo(2025, 861, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 1, 0),
    MobjInfo(2026, 862, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 8388609, 0),
    MobjInfo(2045, 868, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 8388609, 0),
    MobjInfo(83, 857, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 8388609, 0),
    MobjInfo(2007, 870, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 1, 0),
    MobjInfo(2048, 871, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 1, 0),
    MobjInfo(2010, 872, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 1, 0),
    MobjInfo(2046, 873, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 1, 0),
    MobjInfo(2047, 874, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 1, 0),
    MobjInfo(17, 875, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 1, 0),
    MobjInfo(2008, 876, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 1, 0),
    MobjInfo(2049, 877, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 1, 0),
    MobjInfo(8, 878, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 1, 0),
    MobjInfo(2006, 879, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 1, 0),
    MobjInfo(2002, 880, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 1, 0),
    MobjInfo(2005, 881, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 1, 0),
    MobjInfo(2003, 882, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 1, 0),
    MobjInfo(2004, 883, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 1, 0),
    MobjInfo(2001, 884, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 1, 0),
    MobjInfo(82, 885, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 1, 0),
    MobjInfo(85, 959, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 1048576, 100, 0, "", 2, 0),
    MobjInfo(86, 963, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 1048576, 100, 0, "", 2, 0),
    MobjInfo(2028, 886, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 1048576, 100, 0, "", 2, 0),
    MobjInfo(30, 907, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 1048576, 100, 0, "", 2, 0),
    MobjInfo(31, 908, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 1048576, 100, 0, "", 2, 0),
    MobjInfo(32, 909, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 1048576, 100, 0, "", 2, 0),
    MobjInfo(33, 910, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 1048576, 100, 0, "", 2, 0),
    MobjInfo(37, 913, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 1048576, 100, 0, "", 2, 0),
    MobjInfo(36, 924, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 1048576, 100, 0, "", 2, 0),
    MobjInfo(41, 917, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 1048576, 100, 0, "", 2, 0),
    MobjInfo(42, 921, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 1048576, 100, 0, "", 2, 0),
    MobjInfo(43, 914, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 1048576, 100, 0, "", 2, 0),
    MobjInfo(44, 926, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 1048576, 100, 0, "", 2, 0),
    MobjInfo(45, 930, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 1048576, 100, 0, "", 2, 0),
    MobjInfo(46, 934, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 1048576, 100, 0, "", 2, 0),
    MobjInfo(55, 938, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 1048576, 100, 0, "", 2, 0),
    MobjInfo(56, 942, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 1048576, 100, 0, "", 2, 0),
    MobjInfo(57, 946, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 1048576, 100, 0, "", 2, 0),
    MobjInfo(47, 906, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 1048576, 100, 0, "", 2, 0),
    MobjInfo(48, 916, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 1048576, 100, 0, "", 2, 0),
    MobjInfo(34, 911, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 0, 0),
    MobjInfo(35, 912, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 1048576, 100, 0, "", 2, 0),
    MobjInfo(49, 888, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 4456448, 100, 0, "", 770, 0),
    MobjInfo(50, 902, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 5505024, 100, 0, "", 770, 0),
    MobjInfo(51, 903, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 5505024, 100, 0, "", 770, 0),
    MobjInfo(52, 904, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 4456448, 100, 0, "", 770, 0),
    MobjInfo(53, 905, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 3407872, 100, 0, "", 770, 0),
    MobjInfo(59, 902, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 5505024, 100, 0, "", 768, 0),
    MobjInfo(60, 904, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 4456448, 100, 0, "", 768, 0),
    MobjInfo(61, 903, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 3407872, 100, 0, "", 768, 0),
    MobjInfo(62, 905, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 3407872, 100, 0, "", 768, 0),
    MobjInfo(63, 888, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 4456448, 100, 0, "", 768, 0),
    MobjInfo(22, 515, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 0, 0),
    MobjInfo(15, 164, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 0, 0),
    MobjInfo(18, 193, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 0, 0),
    MobjInfo(21, 495, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 0, 0),
    MobjInfo(23, 600, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 0, 0),
    MobjInfo(20, 461, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 0, 0),
    MobjInfo(19, 226, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 0, 0),
    MobjInfo(10, 173, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 0, 0),
    MobjInfo(12, 173, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 0, 0),
    MobjInfo(28, 894, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 1048576, 100, 0, "", 2, 0),
    MobjInfo(24, 895, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 0, 0),
    MobjInfo(27, 896, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 1048576, 100, 0, "", 2, 0),
    MobjInfo(29, 897, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 1048576, 100, 0, "", 2, 0),
    MobjInfo(25, 899, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 1048576, 100, 0, "", 2, 0),
    MobjInfo(26, 900, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 1048576, 100, 0, "", 2, 0),
    MobjInfo(54, 915, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 2097152, 1048576, 100, 0, "", 2, 0),
    MobjInfo(70, 813, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 1048576, 100, 0, "", 2, 0),
    MobjInfo(73, 950, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 5767168, 100, 0, "", 770, 0),
    MobjInfo(74, 951, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 5767168, 100, 0, "", 770, 0),
    MobjInfo(75, 952, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 4194304, 100, 0, "", 770, 0),
    MobjInfo(76, 953, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 4194304, 100, 0, "", 770, 0),
    MobjInfo(77, 954, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 4194304, 100, 0, "", 770, 0),
    MobjInfo(78, 955, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1048576, 4194304, 100, 0, "", 770, 0),
    MobjInfo(79, 956, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 16, 0),
    MobjInfo(80, 957, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 16, 0),
    MobjInfo(81, 958, 1000, 0, "", 8, "", 0, 0, "", 0, 0, 0, 0, "", 0, 1310720, 1048576, 100, 0, "", 16, 0),
]
const ACTIONS = [
    "",
    "Light0",
    "WeaponReady",
    "Lower",
    "Raise",
    "Punch",
    "ReFire",
    "FirePistol",
    "Light1",
    "FireShotgun",
    "Light2",
    "FireShotgun2",
    "CheckReload",
    "OpenShotgun2",
    "LoadShotgun2",
    "CloseShotgun2",
    "FireCGun",
    "GunFlash",
    "FireMissile",
    "Saw",
    "FirePlasma",
    "BFGsound",
    "FireBFG",
    "BFGSpray",
    "Explode",
    "Pain",
    "PlayerScream",
    "Fall",
    "XScream",
    "Look",
    "Chase",
    "FaceTarget",
    "PosAttack",
    "Scream",
    "SPosAttack",
    "VileChase",
    "VileStart",
    "VileTarget",
    "VileAttack",
    "StartFire",
    "Fire",
    "FireCrackle",
    "Tracer",
    "SkelWhoosh",
    "SkelFist",
    "SkelMissile",
    "FatRaise",
    "FatAttack1",
    "FatAttack2",
    "FatAttack3",
    "BossDeath",
    "CPosAttack",
    "CPosRefire",
    "TroopAttack",
    "SargAttack",
    "HeadAttack",
    "BruisAttack",
    "SkullAttack",
    "Metal",
    "SpidRefire",
    "BabyMetal",
    "BspiAttack",
    "Hoof",
    "CyberAttack",
    "PainAttack",
    "PainDie",
    "KeenDie",
    "BrainPain",
    "BrainScream",
    "BrainDie",
    "BrainAwake",
    "BrainSpit",
    "SpawnSound",
    "SpawnFly",
    "BrainExplode",
]
const BY_DOOMED = Dict{Int,Int}(
    2035 => 30,
    5 => 47,
    6 => 49,
    7 => 19,
    8 => 71,
    9 => 2,
    10 => 118,
    12 => 119,
    13 => 48,
    14 => 41,
    2047 => 67,
    16 => 21,
    17 => 68,
    18 => 113,
    19 => 117,
    20 => 116,
    21 => 114,
    22 => 111,
    23 => 115,
    24 => 121,
    25 => 124,
    26 => 125,
    27 => 122,
    28 => 120,
    29 => 123,
    30 => 82,
    31 => 83,
    32 => 84,
    33 => 85,
    34 => 99,
    35 => 100,
    36 => 87,
    37 => 86,
    38 => 51,
    39 => 50,
    40 => 52,
    41 => 88,
    42 => 89,
    43 => 90,
    44 => 91,
    45 => 92,
    46 => 93,
    47 => 97,
    48 => 98,
    49 => 101,
    50 => 102,
    51 => 103,
    52 => 104,
    53 => 105,
    54 => 126,
    55 => 94,
    56 => 95,
    57 => 96,
    58 => 13,
    59 => 106,
    60 => 107,
    61 => 108,
    62 => 109,
    63 => 110,
    64 => 3,
    65 => 10,
    66 => 5,
    67 => 8,
    68 => 20,
    69 => 17,
    70 => 127,
    71 => 22,
    72 => 24,
    73 => 128,
    74 => 129,
    75 => 130,
    76 => 131,
    77 => 132,
    78 => 133,
    79 => 134,
    3001 => 11,
    3002 => 12,
    3003 => 15,
    3004 => 1,
    3005 => 14,
    3006 => 18,
    86 => 80,
    87 => 27,
    88 => 25,
    89 => 26,
    81 => 136,
    2001 => 77,
    2002 => 73,
    2003 => 75,
    2004 => 76,
    2005 => 74,
    2006 => 72,
    2007 => 63,
    2008 => 69,
    80 => 135,
    2010 => 65,
    2011 => 53,
    2012 => 54,
    2013 => 55,
    2014 => 45,
    2015 => 46,
    15 => 112,
    2046 => 66,
    2018 => 43,
    2019 => 44,
    85 => 79,
    82 => 78,
    2022 => 56,
    2023 => 57,
    2024 => 58,
    2025 => 59,
    2026 => 60,
    2049 => 70,
    2028 => 81,
    2048 => 64,
    83 => 62,
    2045 => 61,
    84 => 23,
)
const MI_ACTIVESOUND = 20
const MI_ATTACKSOUND = 6
const MI_DAMAGE = 19
const MI_DEATHSOUND = 14
const MI_DEATHSTATE = 12
const MI_DOOMEDNUM = 0
const MI_FLAGS = 21
const MI_HEIGHT = 17
const MI_MASS = 18
const MI_MELEESTATE = 10
const MI_MISSILESTATE = 11
const MI_PAINCHANCE = 8
const MI_PAINSOUND = 9
const MI_PAINSTATE = 7
const MI_RADIUS = 16
const MI_RAISESTATE = 22
const MI_REACTIONTIME = 5
const MI_SEESOUND = 4
const MI_SEESTATE = 3
const MI_SPAWNHEALTH = 2
const MI_SPAWNSTATE = 1
const MI_SPEED = 15
const MI_XDEATHSTATE = 13
const MT_ARACHPLAZ = 36
const MT_BABY = 20
const MT_BARREL = 30
const MT_BFG = 35
const MT_BLOOD = 38
const MT_BOSSBRAIN = 25
const MT_BOSSSPIT = 26
const MT_BOSSTARGET = 27
const MT_BRUISER = 15
const MT_BRUISERSHOT = 16
const MT_CHAINGUN = 73
const MT_CHAINGUY = 10
const MT_CLIP = 63
const MT_CYBORG = 21
const MT_EXTRABFG = 42
const MT_FATSHOT = 9
const MT_FATSO = 8
const MT_FIRE = 4
const MT_HEAD = 14
const MT_HEADSHOT = 32
const MT_IFOG = 40
const MT_INS = 58
const MT_INV = 56
const MT_KEEN = 24
const MT_KNIGHT = 17
const MT_MEGA = 62
const MT_MISC0 = 43
const MT_MISC1 = 44
const MT_MISC10 = 53
const MT_MISC11 = 54
const MT_MISC12 = 55
const MT_MISC13 = 57
const MT_MISC14 = 59
const MT_MISC15 = 60
const MT_MISC16 = 61
const MT_MISC17 = 64
const MT_MISC18 = 65
const MT_MISC19 = 66
const MT_MISC2 = 45
const MT_MISC20 = 67
const MT_MISC21 = 68
const MT_MISC22 = 69
const MT_MISC23 = 70
const MT_MISC24 = 71
const MT_MISC25 = 72
const MT_MISC26 = 74
const MT_MISC27 = 75
const MT_MISC28 = 76
const MT_MISC29 = 79
const MT_MISC3 = 46
const MT_MISC30 = 80
const MT_MISC31 = 81
const MT_MISC32 = 82
const MT_MISC33 = 83
const MT_MISC34 = 84
const MT_MISC35 = 85
const MT_MISC36 = 86
const MT_MISC37 = 87
const MT_MISC38 = 88
const MT_MISC39 = 89
const MT_MISC4 = 47
const MT_MISC40 = 90
const MT_MISC41 = 91
const MT_MISC42 = 92
const MT_MISC43 = 93
const MT_MISC44 = 94
const MT_MISC45 = 95
const MT_MISC46 = 96
const MT_MISC47 = 97
const MT_MISC48 = 98
const MT_MISC49 = 99
const MT_MISC5 = 48
const MT_MISC50 = 100
const MT_MISC51 = 101
const MT_MISC52 = 102
const MT_MISC53 = 103
const MT_MISC54 = 104
const MT_MISC55 = 105
const MT_MISC56 = 106
const MT_MISC57 = 107
const MT_MISC58 = 108
const MT_MISC59 = 109
const MT_MISC6 = 49
const MT_MISC60 = 110
const MT_MISC61 = 111
const MT_MISC62 = 112
const MT_MISC63 = 113
const MT_MISC64 = 114
const MT_MISC65 = 115
const MT_MISC66 = 116
const MT_MISC67 = 117
const MT_MISC68 = 118
const MT_MISC69 = 119
const MT_MISC7 = 50
const MT_MISC70 = 120
const MT_MISC71 = 121
const MT_MISC72 = 122
const MT_MISC73 = 123
const MT_MISC74 = 124
const MT_MISC75 = 125
const MT_MISC76 = 126
const MT_MISC77 = 127
const MT_MISC78 = 128
const MT_MISC79 = 129
const MT_MISC8 = 51
const MT_MISC80 = 130
const MT_MISC81 = 131
const MT_MISC82 = 132
const MT_MISC83 = 133
const MT_MISC84 = 134
const MT_MISC85 = 135
const MT_MISC86 = 136
const MT_MISC9 = 52
const MT_PAIN = 22
const MT_PLASMA = 34
const MT_PLAYER = 0
const MT_POSSESSED = 1
const MT_PUFF = 37
const MT_ROCKET = 33
const MT_SERGEANT = 12
const MT_SHADOWS = 13
const MT_SHOTGUN = 77
const MT_SHOTGUY = 2
const MT_SKULL = 18
const MT_SMOKE = 7
const MT_SPAWNFIRE = 29
const MT_SPAWNSHOT = 28
const MT_SPIDER = 19
const MT_SUPERSHOTGUN = 78
const MT_TELEPORTMAN = 41
const MT_TFOG = 39
const MT_TRACER = 6
const MT_TROOP = 11
const MT_TROOPSHOT = 31
const MT_UNDEAD = 5
const MT_VILE = 3
const MT_WOLFSS = 23
const S_AMMO = 871
const S_ARACH_PLAZ = 667
const S_ARACH_PLAZ2 = 668
const S_ARACH_PLEX = 669
const S_ARACH_PLEX2 = 670
const S_ARACH_PLEX3 = 671
const S_ARACH_PLEX4 = 672
const S_ARACH_PLEX5 = 673
const S_ARM1 = 802
const S_ARM1A = 803
const S_ARM2 = 804
const S_ARM2A = 805
const S_BAR1 = 806
const S_BAR2 = 807
const S_BBAR1 = 813
const S_BBAR2 = 814
const S_BBAR3 = 815
const S_BEXP = 808
const S_BEXP2 = 809
const S_BEXP3 = 810
const S_BEXP4 = 811
const S_BEXP5 = 812
const S_BFG = 81
const S_BFG1 = 84
const S_BFG2 = 85
const S_BFG3 = 86
const S_BFG4 = 87
const S_BFGDOWN = 82
const S_BFGEXP = 123
const S_BFGEXP2 = 124
const S_BFGEXP3 = 125
const S_BFGEXP4 = 126
const S_BFGFLASH1 = 88
const S_BFGFLASH2 = 89
const S_BFGLAND = 117
const S_BFGLAND2 = 118
const S_BFGLAND3 = 119
const S_BFGLAND4 = 120
const S_BFGLAND5 = 121
const S_BFGLAND6 = 122
const S_BFGSHOT = 115
const S_BFGSHOT2 = 116
const S_BFGUP = 83
const S_BFUG = 879
const S_BIGTREE = 915
const S_BKEY = 828
const S_BKEY2 = 829
const S_BLOOD1 = 90
const S_BLOOD2 = 91
const S_BLOOD3 = 92
const S_BLOODYTWITCH = 888
const S_BLOODYTWITCH2 = 889
const S_BLOODYTWITCH3 = 890
const S_BLOODYTWITCH4 = 891
const S_BLUETORCH = 926
const S_BLUETORCH2 = 927
const S_BLUETORCH3 = 928
const S_BLUETORCH4 = 929
const S_BON1 = 816
const S_BON1A = 817
const S_BON1B = 818
const S_BON1C = 819
const S_BON1D = 820
const S_BON1E = 821
const S_BON2 = 822
const S_BON2A = 823
const S_BON2B = 824
const S_BON2C = 825
const S_BON2D = 826
const S_BON2E = 827
const S_BOS2_ATK1 = 566
const S_BOS2_ATK2 = 567
const S_BOS2_ATK3 = 568
const S_BOS2_DIE1 = 571
const S_BOS2_DIE2 = 572
const S_BOS2_DIE3 = 573
const S_BOS2_DIE4 = 574
const S_BOS2_DIE5 = 575
const S_BOS2_DIE6 = 576
const S_BOS2_DIE7 = 577
const S_BOS2_PAIN = 569
const S_BOS2_PAIN2 = 570
const S_BOS2_RAISE1 = 578
const S_BOS2_RAISE2 = 579
const S_BOS2_RAISE3 = 580
const S_BOS2_RAISE4 = 581
const S_BOS2_RAISE5 = 582
const S_BOS2_RAISE6 = 583
const S_BOS2_RAISE7 = 584
const S_BOS2_RUN1 = 558
const S_BOS2_RUN2 = 559
const S_BOS2_RUN3 = 560
const S_BOS2_RUN4 = 561
const S_BOS2_RUN5 = 562
const S_BOS2_RUN6 = 563
const S_BOS2_RUN7 = 564
const S_BOS2_RUN8 = 565
const S_BOS2_STND = 556
const S_BOS2_STND2 = 557
const S_BOSS_ATK1 = 537
const S_BOSS_ATK2 = 538
const S_BOSS_ATK3 = 539
const S_BOSS_DIE1 = 542
const S_BOSS_DIE2 = 543
const S_BOSS_DIE3 = 544
const S_BOSS_DIE4 = 545
const S_BOSS_DIE5 = 546
const S_BOSS_DIE6 = 547
const S_BOSS_DIE7 = 548
const S_BOSS_PAIN = 540
const S_BOSS_PAIN2 = 541
const S_BOSS_RAISE1 = 549
const S_BOSS_RAISE2 = 550
const S_BOSS_RAISE3 = 551
const S_BOSS_RAISE4 = 552
const S_BOSS_RAISE5 = 553
const S_BOSS_RAISE6 = 554
const S_BOSS_RAISE7 = 555
const S_BOSS_RUN1 = 529
const S_BOSS_RUN2 = 530
const S_BOSS_RUN3 = 531
const S_BOSS_RUN4 = 532
const S_BOSS_RUN5 = 533
const S_BOSS_RUN6 = 534
const S_BOSS_RUN7 = 535
const S_BOSS_RUN8 = 536
const S_BOSS_STND = 527
const S_BOSS_STND2 = 528
const S_BPAK = 878
const S_BRAIN = 778
const S_BRAINEXPLODE1 = 799
const S_BRAINEXPLODE2 = 800
const S_BRAINEXPLODE3 = 801
const S_BRAINEYE = 784
const S_BRAINEYE1 = 786
const S_BRAINEYESEE = 785
const S_BRAINSTEM = 958
const S_BRAIN_DIE1 = 780
const S_BRAIN_DIE2 = 781
const S_BRAIN_DIE3 = 782
const S_BRAIN_DIE4 = 783
const S_BRAIN_PAIN = 779
const S_BRBALL1 = 522
const S_BRBALL2 = 523
const S_BRBALLX1 = 524
const S_BRBALLX2 = 525
const S_BRBALLX3 = 526
const S_BROK = 873
const S_BSKULL = 834
const S_BSKULL2 = 835
const S_BSPI_ATK1 = 647
const S_BSPI_ATK2 = 648
const S_BSPI_ATK3 = 649
const S_BSPI_ATK4 = 650
const S_BSPI_DIE1 = 653
const S_BSPI_DIE2 = 654
const S_BSPI_DIE3 = 655
const S_BSPI_DIE4 = 656
const S_BSPI_DIE5 = 657
const S_BSPI_DIE6 = 658
const S_BSPI_DIE7 = 659
const S_BSPI_PAIN = 651
const S_BSPI_PAIN2 = 652
const S_BSPI_RAISE1 = 660
const S_BSPI_RAISE2 = 661
const S_BSPI_RAISE3 = 662
const S_BSPI_RAISE4 = 663
const S_BSPI_RAISE5 = 664
const S_BSPI_RAISE6 = 665
const S_BSPI_RAISE7 = 666
const S_BSPI_RUN1 = 635
const S_BSPI_RUN10 = 644
const S_BSPI_RUN11 = 645
const S_BSPI_RUN12 = 646
const S_BSPI_RUN2 = 636
const S_BSPI_RUN3 = 637
const S_BSPI_RUN4 = 638
const S_BSPI_RUN5 = 639
const S_BSPI_RUN6 = 640
const S_BSPI_RUN7 = 641
const S_BSPI_RUN8 = 642
const S_BSPI_RUN9 = 643
const S_BSPI_SIGHT = 634
const S_BSPI_STND = 632
const S_BSPI_STND2 = 633
const S_BTORCHSHRT = 938
const S_BTORCHSHRT2 = 939
const S_BTORCHSHRT3 = 940
const S_BTORCHSHRT4 = 941
const S_CANDELABRA = 912
const S_CANDLESTIK = 911
const S_CELL = 874
const S_CELP = 875
const S_CHAIN = 49
const S_CHAIN1 = 52
const S_CHAIN2 = 53
const S_CHAIN3 = 54
const S_CHAINDOWN = 50
const S_CHAINFLASH1 = 55
const S_CHAINFLASH2 = 56
const S_CHAINUP = 51
const S_CLIP = 870
const S_COLONGIBS = 956
const S_COLU = 886
const S_COMMKEEN = 764
const S_COMMKEEN10 = 773
const S_COMMKEEN11 = 774
const S_COMMKEEN12 = 775
const S_COMMKEEN2 = 765
const S_COMMKEEN3 = 766
const S_COMMKEEN4 = 767
const S_COMMKEEN5 = 768
const S_COMMKEEN6 = 769
const S_COMMKEEN7 = 770
const S_COMMKEEN8 = 771
const S_COMMKEEN9 = 772
const S_CPOS_ATK1 = 416
const S_CPOS_ATK2 = 417
const S_CPOS_ATK3 = 418
const S_CPOS_ATK4 = 419
const S_CPOS_DIE1 = 422
const S_CPOS_DIE2 = 423
const S_CPOS_DIE3 = 424
const S_CPOS_DIE4 = 425
const S_CPOS_DIE5 = 426
const S_CPOS_DIE6 = 427
const S_CPOS_DIE7 = 428
const S_CPOS_PAIN = 420
const S_CPOS_PAIN2 = 421
const S_CPOS_RAISE1 = 435
const S_CPOS_RAISE2 = 436
const S_CPOS_RAISE3 = 437
const S_CPOS_RAISE4 = 438
const S_CPOS_RAISE5 = 439
const S_CPOS_RAISE6 = 440
const S_CPOS_RAISE7 = 441
const S_CPOS_RUN1 = 408
const S_CPOS_RUN2 = 409
const S_CPOS_RUN3 = 410
const S_CPOS_RUN4 = 411
const S_CPOS_RUN5 = 412
const S_CPOS_RUN6 = 413
const S_CPOS_RUN7 = 414
const S_CPOS_RUN8 = 415
const S_CPOS_STND = 406
const S_CPOS_STND2 = 407
const S_CPOS_XDIE1 = 429
const S_CPOS_XDIE2 = 430
const S_CPOS_XDIE3 = 431
const S_CPOS_XDIE4 = 432
const S_CPOS_XDIE5 = 433
const S_CPOS_XDIE6 = 434
const S_CSAW = 881
const S_CYBER_ATK1 = 684
const S_CYBER_ATK2 = 685
const S_CYBER_ATK3 = 686
const S_CYBER_ATK4 = 687
const S_CYBER_ATK5 = 688
const S_CYBER_ATK6 = 689
const S_CYBER_DIE1 = 691
const S_CYBER_DIE10 = 700
const S_CYBER_DIE2 = 692
const S_CYBER_DIE3 = 693
const S_CYBER_DIE4 = 694
const S_CYBER_DIE5 = 695
const S_CYBER_DIE6 = 696
const S_CYBER_DIE7 = 697
const S_CYBER_DIE8 = 698
const S_CYBER_DIE9 = 699
const S_CYBER_PAIN = 690
const S_CYBER_RUN1 = 676
const S_CYBER_RUN2 = 677
const S_CYBER_RUN3 = 678
const S_CYBER_RUN4 = 679
const S_CYBER_RUN5 = 680
const S_CYBER_RUN6 = 681
const S_CYBER_RUN7 = 682
const S_CYBER_RUN8 = 683
const S_CYBER_STND = 674
const S_CYBER_STND2 = 675
const S_DEADBOTTOM = 893
const S_DEADSTICK = 899
const S_DEADTORSO = 892
const S_DSGUN = 32
const S_DSGUN1 = 35
const S_DSGUN10 = 44
const S_DSGUN2 = 36
const S_DSGUN3 = 37
const S_DSGUN4 = 38
const S_DSGUN5 = 39
const S_DSGUN6 = 40
const S_DSGUN7 = 41
const S_DSGUN8 = 42
const S_DSGUN9 = 43
const S_DSGUNDOWN = 33
const S_DSGUNFLASH1 = 47
const S_DSGUNFLASH2 = 48
const S_DSGUNUP = 34
const S_DSNR1 = 45
const S_DSNR2 = 46
const S_EVILEYE = 917
const S_EVILEYE2 = 918
const S_EVILEYE3 = 919
const S_EVILEYE4 = 920
const S_EXPLODE1 = 127
const S_EXPLODE2 = 128
const S_EXPLODE3 = 129
const S_FATSHOT1 = 357
const S_FATSHOT2 = 358
const S_FATSHOTX1 = 359
const S_FATSHOTX2 = 360
const S_FATSHOTX3 = 361
const S_FATT_ATK1 = 376
const S_FATT_ATK10 = 385
const S_FATT_ATK2 = 377
const S_FATT_ATK3 = 378
const S_FATT_ATK4 = 379
const S_FATT_ATK5 = 380
const S_FATT_ATK6 = 381
const S_FATT_ATK7 = 382
const S_FATT_ATK8 = 383
const S_FATT_ATK9 = 384
const S_FATT_DIE1 = 388
const S_FATT_DIE10 = 397
const S_FATT_DIE2 = 389
const S_FATT_DIE3 = 390
const S_FATT_DIE4 = 391
const S_FATT_DIE5 = 392
const S_FATT_DIE6 = 393
const S_FATT_DIE7 = 394
const S_FATT_DIE8 = 395
const S_FATT_DIE9 = 396
const S_FATT_PAIN = 386
const S_FATT_PAIN2 = 387
const S_FATT_RAISE1 = 398
const S_FATT_RAISE2 = 399
const S_FATT_RAISE3 = 400
const S_FATT_RAISE4 = 401
const S_FATT_RAISE5 = 402
const S_FATT_RAISE6 = 403
const S_FATT_RAISE7 = 404
const S_FATT_RAISE8 = 405
const S_FATT_RUN1 = 364
const S_FATT_RUN10 = 373
const S_FATT_RUN11 = 374
const S_FATT_RUN12 = 375
const S_FATT_RUN2 = 365
const S_FATT_RUN3 = 366
const S_FATT_RUN4 = 367
const S_FATT_RUN5 = 368
const S_FATT_RUN6 = 369
const S_FATT_RUN7 = 370
const S_FATT_RUN8 = 371
const S_FATT_RUN9 = 372
const S_FATT_STND = 362
const S_FATT_STND2 = 363
const S_FIRE1 = 281
const S_FIRE10 = 290
const S_FIRE11 = 291
const S_FIRE12 = 292
const S_FIRE13 = 293
const S_FIRE14 = 294
const S_FIRE15 = 295
const S_FIRE16 = 296
const S_FIRE17 = 297
const S_FIRE18 = 298
const S_FIRE19 = 299
const S_FIRE2 = 282
const S_FIRE20 = 300
const S_FIRE21 = 301
const S_FIRE22 = 302
const S_FIRE23 = 303
const S_FIRE24 = 304
const S_FIRE25 = 305
const S_FIRE26 = 306
const S_FIRE27 = 307
const S_FIRE28 = 308
const S_FIRE29 = 309
const S_FIRE3 = 283
const S_FIRE30 = 310
const S_FIRE4 = 284
const S_FIRE5 = 285
const S_FIRE6 = 286
const S_FIRE7 = 287
const S_FIRE8 = 288
const S_FIRE9 = 289
const S_FLOATSKULL = 921
const S_FLOATSKULL2 = 922
const S_FLOATSKULL3 = 923
const S_GIBS = 895
const S_GREENTORCH = 930
const S_GREENTORCH2 = 931
const S_GREENTORCH3 = 932
const S_GREENTORCH4 = 933
const S_GTORCHSHRT = 942
const S_GTORCHSHRT2 = 943
const S_GTORCHSHRT3 = 944
const S_GTORCHSHRT4 = 945
const S_HANGBNOBRAIN = 951
const S_HANGNOGUTS = 950
const S_HANGTLOOKDN = 952
const S_HANGTLOOKUP = 954
const S_HANGTNOBRAIN = 955
const S_HANGTSKULL = 953
const S_HEADCANDLES = 897
const S_HEADCANDLES2 = 898
const S_HEADONASTICK = 896
const S_HEADSONSTICK = 894
const S_HEAD_ATK1 = 504
const S_HEAD_ATK2 = 505
const S_HEAD_ATK3 = 506
const S_HEAD_DIE1 = 510
const S_HEAD_DIE2 = 511
const S_HEAD_DIE3 = 512
const S_HEAD_DIE4 = 513
const S_HEAD_DIE5 = 514
const S_HEAD_DIE6 = 515
const S_HEAD_PAIN = 507
const S_HEAD_PAIN2 = 508
const S_HEAD_PAIN3 = 509
const S_HEAD_RAISE1 = 516
const S_HEAD_RAISE2 = 517
const S_HEAD_RAISE3 = 518
const S_HEAD_RAISE4 = 519
const S_HEAD_RAISE5 = 520
const S_HEAD_RAISE6 = 521
const S_HEAD_RUN1 = 503
const S_HEAD_STND = 502
const S_HEARTCOL = 924
const S_HEARTCOL2 = 925
const S_IFOG = 142
const S_IFOG01 = 143
const S_IFOG02 = 144
const S_IFOG2 = 145
const S_IFOG3 = 146
const S_IFOG4 = 147
const S_IFOG5 = 148
const S_KEENPAIN = 776
const S_KEENPAIN2 = 777
const S_KEENSTND = 763
const S_LAUN = 882
const S_LIGHTDONE = 1
const S_LIVESTICK = 900
const S_LIVESTICK2 = 901
const S_MEAT2 = 902
const S_MEAT3 = 903
const S_MEAT4 = 904
const S_MEAT5 = 905
const S_MEDI = 841
const S_MEGA = 857
const S_MEGA2 = 858
const S_MEGA3 = 859
const S_MEGA4 = 860
const S_MGUN = 880
const S_MISSILE = 57
const S_MISSILE1 = 60
const S_MISSILE2 = 61
const S_MISSILE3 = 62
const S_MISSILEDOWN = 58
const S_MISSILEFLASH1 = 63
const S_MISSILEFLASH2 = 64
const S_MISSILEFLASH3 = 65
const S_MISSILEFLASH4 = 66
const S_MISSILEUP = 59
const S_NULL = 0
const S_PAIN_ATK1 = 708
const S_PAIN_ATK2 = 709
const S_PAIN_ATK3 = 710
const S_PAIN_ATK4 = 711
const S_PAIN_DIE1 = 714
const S_PAIN_DIE2 = 715
const S_PAIN_DIE3 = 716
const S_PAIN_DIE4 = 717
const S_PAIN_DIE5 = 718
const S_PAIN_DIE6 = 719
const S_PAIN_PAIN = 712
const S_PAIN_PAIN2 = 713
const S_PAIN_RAISE1 = 720
const S_PAIN_RAISE2 = 721
const S_PAIN_RAISE3 = 722
const S_PAIN_RAISE4 = 723
const S_PAIN_RAISE5 = 724
const S_PAIN_RAISE6 = 725
const S_PAIN_RUN1 = 702
const S_PAIN_RUN2 = 703
const S_PAIN_RUN3 = 704
const S_PAIN_RUN4 = 705
const S_PAIN_RUN5 = 706
const S_PAIN_RUN6 = 707
const S_PAIN_STND = 701
const S_PINS = 853
const S_PINS2 = 854
const S_PINS3 = 855
const S_PINS4 = 856
const S_PINV = 848
const S_PINV2 = 849
const S_PINV3 = 850
const S_PINV4 = 851
const S_PISTOL = 10
const S_PISTOL1 = 13
const S_PISTOL2 = 14
const S_PISTOL3 = 15
const S_PISTOL4 = 16
const S_PISTOLDOWN = 11
const S_PISTOLFLASH = 17
const S_PISTOLUP = 12
const S_PLAS = 883
const S_PLASBALL = 107
const S_PLASBALL2 = 108
const S_PLASEXP = 109
const S_PLASEXP2 = 110
const S_PLASEXP3 = 111
const S_PLASEXP4 = 112
const S_PLASEXP5 = 113
const S_PLASMA = 74
const S_PLASMA1 = 77
const S_PLASMA2 = 78
const S_PLASMADOWN = 75
const S_PLASMAFLASH1 = 79
const S_PLASMAFLASH2 = 80
const S_PLASMAUP = 76
const S_PLAY = 149
const S_PLAY_ATK1 = 154
const S_PLAY_ATK2 = 155
const S_PLAY_DIE1 = 158
const S_PLAY_DIE2 = 159
const S_PLAY_DIE3 = 160
const S_PLAY_DIE4 = 161
const S_PLAY_DIE5 = 162
const S_PLAY_DIE6 = 163
const S_PLAY_DIE7 = 164
const S_PLAY_PAIN = 156
const S_PLAY_PAIN2 = 157
const S_PLAY_RUN1 = 150
const S_PLAY_RUN2 = 151
const S_PLAY_RUN3 = 152
const S_PLAY_RUN4 = 153
const S_PLAY_XDIE1 = 165
const S_PLAY_XDIE2 = 166
const S_PLAY_XDIE3 = 167
const S_PLAY_XDIE4 = 168
const S_PLAY_XDIE5 = 169
const S_PLAY_XDIE6 = 170
const S_PLAY_XDIE7 = 171
const S_PLAY_XDIE8 = 172
const S_PLAY_XDIE9 = 173
const S_PMAP = 862
const S_PMAP2 = 863
const S_PMAP3 = 864
const S_PMAP4 = 865
const S_PMAP5 = 866
const S_PMAP6 = 867
const S_POSS_ATK1 = 184
const S_POSS_ATK2 = 185
const S_POSS_ATK3 = 186
const S_POSS_DIE1 = 189
const S_POSS_DIE2 = 190
const S_POSS_DIE3 = 191
const S_POSS_DIE4 = 192
const S_POSS_DIE5 = 193
const S_POSS_PAIN = 187
const S_POSS_PAIN2 = 188
const S_POSS_RAISE1 = 203
const S_POSS_RAISE2 = 204
const S_POSS_RAISE3 = 205
const S_POSS_RAISE4 = 206
const S_POSS_RUN1 = 176
const S_POSS_RUN2 = 177
const S_POSS_RUN3 = 178
const S_POSS_RUN4 = 179
const S_POSS_RUN5 = 180
const S_POSS_RUN6 = 181
const S_POSS_RUN7 = 182
const S_POSS_RUN8 = 183
const S_POSS_STND = 174
const S_POSS_STND2 = 175
const S_POSS_XDIE1 = 194
const S_POSS_XDIE2 = 195
const S_POSS_XDIE3 = 196
const S_POSS_XDIE4 = 197
const S_POSS_XDIE5 = 198
const S_POSS_XDIE6 = 199
const S_POSS_XDIE7 = 200
const S_POSS_XDIE8 = 201
const S_POSS_XDIE9 = 202
const S_PSTR = 852
const S_PUFF1 = 93
const S_PUFF2 = 94
const S_PUFF3 = 95
const S_PUFF4 = 96
const S_PUNCH = 2
const S_PUNCH1 = 5
const S_PUNCH2 = 6
const S_PUNCH3 = 7
const S_PUNCH4 = 8
const S_PUNCH5 = 9
const S_PUNCHDOWN = 3
const S_PUNCHUP = 4
const S_PVIS = 868
const S_PVIS2 = 869
const S_RBALL1 = 102
const S_RBALL2 = 103
const S_RBALLX1 = 104
const S_RBALLX2 = 105
const S_RBALLX3 = 106
const S_REDTORCH = 934
const S_REDTORCH2 = 935
const S_REDTORCH3 = 936
const S_REDTORCH4 = 937
const S_RKEY = 830
const S_RKEY2 = 831
const S_ROCK = 872
const S_ROCKET = 114
const S_RSKULL = 836
const S_RSKULL2 = 837
const S_RTORCHSHRT = 946
const S_RTORCHSHRT2 = 947
const S_RTORCHSHRT3 = 948
const S_RTORCHSHRT4 = 949
const S_SARG_ATK1 = 485
const S_SARG_ATK2 = 486
const S_SARG_ATK3 = 487
const S_SARG_DIE1 = 490
const S_SARG_DIE2 = 491
const S_SARG_DIE3 = 492
const S_SARG_DIE4 = 493
const S_SARG_DIE5 = 494
const S_SARG_DIE6 = 495
const S_SARG_PAIN = 488
const S_SARG_PAIN2 = 489
const S_SARG_RAISE1 = 496
const S_SARG_RAISE2 = 497
const S_SARG_RAISE3 = 498
const S_SARG_RAISE4 = 499
const S_SARG_RAISE5 = 500
const S_SARG_RAISE6 = 501
const S_SARG_RUN1 = 477
const S_SARG_RUN2 = 478
const S_SARG_RUN3 = 479
const S_SARG_RUN4 = 480
const S_SARG_RUN5 = 481
const S_SARG_RUN6 = 482
const S_SARG_RUN7 = 483
const S_SARG_RUN8 = 484
const S_SARG_STND = 475
const S_SARG_STND2 = 476
const S_SAW = 67
const S_SAW1 = 71
const S_SAW2 = 72
const S_SAW3 = 73
const S_SAWB = 68
const S_SAWDOWN = 69
const S_SAWUP = 70
const S_SBOX = 877
const S_SGUN = 18
const S_SGUN1 = 21
const S_SGUN2 = 22
const S_SGUN3 = 23
const S_SGUN4 = 24
const S_SGUN5 = 25
const S_SGUN6 = 26
const S_SGUN7 = 27
const S_SGUN8 = 28
const S_SGUN9 = 29
const S_SGUNDOWN = 19
const S_SGUNFLASH1 = 30
const S_SGUNFLASH2 = 31
const S_SGUNUP = 20
const S_SHEL = 876
const S_SHOT = 884
const S_SHOT2 = 885
const S_SHRTGRNCOL = 908
const S_SHRTREDCOL = 910
const S_SKEL_DIE1 = 345
const S_SKEL_DIE2 = 346
const S_SKEL_DIE3 = 347
const S_SKEL_DIE4 = 348
const S_SKEL_DIE5 = 349
const S_SKEL_DIE6 = 350
const S_SKEL_FIST1 = 335
const S_SKEL_FIST2 = 336
const S_SKEL_FIST3 = 337
const S_SKEL_FIST4 = 338
const S_SKEL_MISS1 = 339
const S_SKEL_MISS2 = 340
const S_SKEL_MISS3 = 341
const S_SKEL_MISS4 = 342
const S_SKEL_PAIN = 343
const S_SKEL_PAIN2 = 344
const S_SKEL_RAISE1 = 351
const S_SKEL_RAISE2 = 352
const S_SKEL_RAISE3 = 353
const S_SKEL_RAISE4 = 354
const S_SKEL_RAISE5 = 355
const S_SKEL_RAISE6 = 356
const S_SKEL_RUN1 = 323
const S_SKEL_RUN10 = 332
const S_SKEL_RUN11 = 333
const S_SKEL_RUN12 = 334
const S_SKEL_RUN2 = 324
const S_SKEL_RUN3 = 325
const S_SKEL_RUN4 = 326
const S_SKEL_RUN5 = 327
const S_SKEL_RUN6 = 328
const S_SKEL_RUN7 = 329
const S_SKEL_RUN8 = 330
const S_SKEL_RUN9 = 331
const S_SKEL_STND = 321
const S_SKEL_STND2 = 322
const S_SKULLCOL = 913
const S_SKULL_ATK1 = 589
const S_SKULL_ATK2 = 590
const S_SKULL_ATK3 = 591
const S_SKULL_ATK4 = 592
const S_SKULL_DIE1 = 595
const S_SKULL_DIE2 = 596
const S_SKULL_DIE3 = 597
const S_SKULL_DIE4 = 598
const S_SKULL_DIE5 = 599
const S_SKULL_DIE6 = 600
const S_SKULL_PAIN = 593
const S_SKULL_PAIN2 = 594
const S_SKULL_RUN1 = 587
const S_SKULL_RUN2 = 588
const S_SKULL_STND = 585
const S_SKULL_STND2 = 586
const S_SMALLPOOL = 957
const S_SMOKE1 = 311
const S_SMOKE2 = 312
const S_SMOKE3 = 313
const S_SMOKE4 = 314
const S_SMOKE5 = 315
const S_SOUL = 842
const S_SOUL2 = 843
const S_SOUL3 = 844
const S_SOUL4 = 845
const S_SOUL5 = 846
const S_SOUL6 = 847
const S_SPAWN1 = 787
const S_SPAWN2 = 788
const S_SPAWN3 = 789
const S_SPAWN4 = 790
const S_SPAWNFIRE1 = 791
const S_SPAWNFIRE2 = 792
const S_SPAWNFIRE3 = 793
const S_SPAWNFIRE4 = 794
const S_SPAWNFIRE5 = 795
const S_SPAWNFIRE6 = 796
const S_SPAWNFIRE7 = 797
const S_SPAWNFIRE8 = 798
const S_SPID_ATK1 = 615
const S_SPID_ATK2 = 616
const S_SPID_ATK3 = 617
const S_SPID_ATK4 = 618
const S_SPID_DIE1 = 621
const S_SPID_DIE10 = 630
const S_SPID_DIE11 = 631
const S_SPID_DIE2 = 622
const S_SPID_DIE3 = 623
const S_SPID_DIE4 = 624
const S_SPID_DIE5 = 625
const S_SPID_DIE6 = 626
const S_SPID_DIE7 = 627
const S_SPID_DIE8 = 628
const S_SPID_DIE9 = 629
const S_SPID_PAIN = 619
const S_SPID_PAIN2 = 620
const S_SPID_RUN1 = 603
const S_SPID_RUN10 = 612
const S_SPID_RUN11 = 613
const S_SPID_RUN12 = 614
const S_SPID_RUN2 = 604
const S_SPID_RUN3 = 605
const S_SPID_RUN4 = 606
const S_SPID_RUN5 = 607
const S_SPID_RUN6 = 608
const S_SPID_RUN7 = 609
const S_SPID_RUN8 = 610
const S_SPID_RUN9 = 611
const S_SPID_STND = 601
const S_SPID_STND2 = 602
const S_SPOS_ATK1 = 217
const S_SPOS_ATK2 = 218
const S_SPOS_ATK3 = 219
const S_SPOS_DIE1 = 222
const S_SPOS_DIE2 = 223
const S_SPOS_DIE3 = 224
const S_SPOS_DIE4 = 225
const S_SPOS_DIE5 = 226
const S_SPOS_PAIN = 220
const S_SPOS_PAIN2 = 221
const S_SPOS_RAISE1 = 236
const S_SPOS_RAISE2 = 237
const S_SPOS_RAISE3 = 238
const S_SPOS_RAISE4 = 239
const S_SPOS_RAISE5 = 240
const S_SPOS_RUN1 = 209
const S_SPOS_RUN2 = 210
const S_SPOS_RUN3 = 211
const S_SPOS_RUN4 = 212
const S_SPOS_RUN5 = 213
const S_SPOS_RUN6 = 214
const S_SPOS_RUN7 = 215
const S_SPOS_RUN8 = 216
const S_SPOS_STND = 207
const S_SPOS_STND2 = 208
const S_SPOS_XDIE1 = 227
const S_SPOS_XDIE2 = 228
const S_SPOS_XDIE3 = 229
const S_SPOS_XDIE4 = 230
const S_SPOS_XDIE5 = 231
const S_SPOS_XDIE6 = 232
const S_SPOS_XDIE7 = 233
const S_SPOS_XDIE8 = 234
const S_SPOS_XDIE9 = 235
const S_SSWV_ATK1 = 736
const S_SSWV_ATK2 = 737
const S_SSWV_ATK3 = 738
const S_SSWV_ATK4 = 739
const S_SSWV_ATK5 = 740
const S_SSWV_ATK6 = 741
const S_SSWV_DIE1 = 744
const S_SSWV_DIE2 = 745
const S_SSWV_DIE3 = 746
const S_SSWV_DIE4 = 747
const S_SSWV_DIE5 = 748
const S_SSWV_PAIN = 742
const S_SSWV_PAIN2 = 743
const S_SSWV_RAISE1 = 758
const S_SSWV_RAISE2 = 759
const S_SSWV_RAISE3 = 760
const S_SSWV_RAISE4 = 761
const S_SSWV_RAISE5 = 762
const S_SSWV_RUN1 = 728
const S_SSWV_RUN2 = 729
const S_SSWV_RUN3 = 730
const S_SSWV_RUN4 = 731
const S_SSWV_RUN5 = 732
const S_SSWV_RUN6 = 733
const S_SSWV_RUN7 = 734
const S_SSWV_RUN8 = 735
const S_SSWV_STND = 726
const S_SSWV_STND2 = 727
const S_SSWV_XDIE1 = 749
const S_SSWV_XDIE2 = 750
const S_SSWV_XDIE3 = 751
const S_SSWV_XDIE4 = 752
const S_SSWV_XDIE5 = 753
const S_SSWV_XDIE6 = 754
const S_SSWV_XDIE7 = 755
const S_SSWV_XDIE8 = 756
const S_SSWV_XDIE9 = 757
const S_STALAG = 887
const S_STALAGTITE = 906
const S_STIM = 840
const S_SUIT = 861
const S_TALLGRNCOL = 907
const S_TALLREDCOL = 909
const S_TBALL1 = 97
const S_TBALL2 = 98
const S_TBALLX1 = 99
const S_TBALLX2 = 100
const S_TBALLX3 = 101
const S_TECH2LAMP = 963
const S_TECH2LAMP2 = 964
const S_TECH2LAMP3 = 965
const S_TECH2LAMP4 = 966
const S_TECHLAMP = 959
const S_TECHLAMP2 = 960
const S_TECHLAMP3 = 961
const S_TECHLAMP4 = 962
const S_TECHPILLAR = 916
const S_TFOG = 130
const S_TFOG01 = 131
const S_TFOG02 = 132
const S_TFOG10 = 141
const S_TFOG2 = 133
const S_TFOG3 = 134
const S_TFOG4 = 135
const S_TFOG5 = 136
const S_TFOG6 = 137
const S_TFOG7 = 138
const S_TFOG8 = 139
const S_TFOG9 = 140
const S_TORCHTREE = 914
const S_TRACEEXP1 = 318
const S_TRACEEXP2 = 319
const S_TRACEEXP3 = 320
const S_TRACER = 316
const S_TRACER2 = 317
const S_TROO_ATK1 = 452
const S_TROO_ATK2 = 453
const S_TROO_ATK3 = 454
const S_TROO_DIE1 = 457
const S_TROO_DIE2 = 458
const S_TROO_DIE3 = 459
const S_TROO_DIE4 = 460
const S_TROO_DIE5 = 461
const S_TROO_PAIN = 455
const S_TROO_PAIN2 = 456
const S_TROO_RAISE1 = 470
const S_TROO_RAISE2 = 471
const S_TROO_RAISE3 = 472
const S_TROO_RAISE4 = 473
const S_TROO_RAISE5 = 474
const S_TROO_RUN1 = 444
const S_TROO_RUN2 = 445
const S_TROO_RUN3 = 446
const S_TROO_RUN4 = 447
const S_TROO_RUN5 = 448
const S_TROO_RUN6 = 449
const S_TROO_RUN7 = 450
const S_TROO_RUN8 = 451
const S_TROO_STND = 442
const S_TROO_STND2 = 443
const S_TROO_XDIE1 = 462
const S_TROO_XDIE2 = 463
const S_TROO_XDIE3 = 464
const S_TROO_XDIE4 = 465
const S_TROO_XDIE5 = 466
const S_TROO_XDIE6 = 467
const S_TROO_XDIE7 = 468
const S_TROO_XDIE8 = 469
const S_VILE_ATK1 = 255
const S_VILE_ATK10 = 264
const S_VILE_ATK11 = 265
const S_VILE_ATK2 = 256
const S_VILE_ATK3 = 257
const S_VILE_ATK4 = 258
const S_VILE_ATK5 = 259
const S_VILE_ATK6 = 260
const S_VILE_ATK7 = 261
const S_VILE_ATK8 = 262
const S_VILE_ATK9 = 263
const S_VILE_DIE1 = 271
const S_VILE_DIE10 = 280
const S_VILE_DIE2 = 272
const S_VILE_DIE3 = 273
const S_VILE_DIE4 = 274
const S_VILE_DIE5 = 275
const S_VILE_DIE6 = 276
const S_VILE_DIE7 = 277
const S_VILE_DIE8 = 278
const S_VILE_DIE9 = 279
const S_VILE_HEAL1 = 266
const S_VILE_HEAL2 = 267
const S_VILE_HEAL3 = 268
const S_VILE_PAIN = 269
const S_VILE_PAIN2 = 270
const S_VILE_RUN1 = 243
const S_VILE_RUN10 = 252
const S_VILE_RUN11 = 253
const S_VILE_RUN12 = 254
const S_VILE_RUN2 = 244
const S_VILE_RUN3 = 245
const S_VILE_RUN4 = 246
const S_VILE_RUN5 = 247
const S_VILE_RUN6 = 248
const S_VILE_RUN7 = 249
const S_VILE_RUN8 = 250
const S_VILE_RUN9 = 251
const S_VILE_STND = 241
const S_VILE_STND2 = 242
const S_YKEY = 832
const S_YKEY2 = 833
const S_YSKULL = 838
const S_YSKULL2 = 839
# counts spr 138 states 967 mobj 137 actions 75

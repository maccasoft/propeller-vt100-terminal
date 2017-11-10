OBJ

    kb : "keyboard"

PUB null
'' This is not a top level object.

PUB get_map
    return @keymap

PUB map(k, mod) | i
    return WORD[@keymap][k * 4 + mod]

DAT

keymap
    '       Normal             Shift              AltGR              Shift+AltGR
    word    kb#KeyNone,        kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x00
    word    kb#KeyNone,        kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x01
    word    kb#KeyNone,        kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x02
    word    kb#KeyNone,        kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x03
    word    "a",               "A",               kb#KeyNone,        kb#KeyNone         ' 0x04
    word    "b",               "B",               kb#KeyNone,        kb#KeyNone         ' 0x05
    word    "c",               "C",               kb#KeyNone,        kb#KeyNone         ' 0x06
    word    "d",               "D",               kb#KeyNone,        kb#KeyNone         ' 0x07
    word    "e",               "E",               $EE,               $EE                ' 0x08
    word    "f",               "F",               kb#KeyNone,        kb#KeyNone         ' 0x09
    word    "g",               "G",               kb#KeyNone,        kb#KeyNone         ' 0x0A
    word    "h",               "H",               kb#KeyNone,        kb#KeyNone         ' 0x0B
    word    "i",               "I",               kb#KeyNone,        kb#KeyNone         ' 0x0C
    word    "j",               "J",               kb#KeyNone,        kb#KeyNone         ' 0x0D
    word    "k",               "K",               kb#KeyNone,        kb#KeyNone         ' 0x0E
    word    "l",               "L",               kb#KeyNone,        kb#KeyNone         ' 0x0F
    word    "m",               "M",               kb#KeyNone,        kb#KeyNone         ' 0x10
    word    "n",               "N",               kb#KeyNone,        kb#KeyNone         ' 0x11
    word    "o",               "O",               kb#KeyNone,        kb#KeyNone         ' 0x12
    word    "p",               "P",               kb#KeyNone,        kb#KeyNone         ' 0x13
    word    "q",               "Q",               kb#KeyNone,        kb#KeyNone         ' 0x14
    word    "r",               "R",               kb#KeyNone,        kb#KeyNone         ' 0x15
    word    "s",               "S",               kb#KeyNone,        kb#KeyNone         ' 0x16
    word    "t",               "T",               kb#KeyNone,        kb#KeyNone         ' 0x17
    word    "u",               "U",               kb#KeyNone,        kb#KeyNone         ' 0x18
    word    "v",               "V",               kb#KeyNone,        kb#KeyNone         ' 0x19
    word    "w",               "W",               kb#KeyNone,        kb#KeyNone         ' 0x1A
    word    "x",               "X",               kb#KeyNone,        kb#KeyNone         ' 0x1B
    word    "y",               "Y",               kb#KeyNone,        kb#KeyNone         ' 0x1C
    word    "z",               "Z",               kb#KeyNone,        kb#KeyNone         ' 0x1D
    word    "1",               "!",               kb#KeyNone,        kb#KeyNone         ' 0x1E
    word    "2",               $22,               kb#KeyNone,        kb#KeyNone         ' 0x1F
    word    "3",               $9C,               kb#KeyNone,        kb#KeyNone         ' 0x20
    word    "4",               "$",               kb#KeyNone,        kb#KeyNone         ' 0x21
    word    "5",               "%",               $80,               $80                ' 0x22
    word    "6",               "&",               kb#KeyNone,        kb#KeyNone         ' 0x23
    word    "7",               "/",               kb#KeyNone,        kb#KeyNone         ' 0x24
    word    "8",               "(",               kb#KeyNone,        kb#KeyNone         ' 0x25
    word    "9",               ")",               kb#KeyNone,        kb#KeyNone         ' 0x26
    word    "0",               "=",               kb#KeyNone,        kb#KeyNone         ' 0x27
    word    $0D,               $0D,               kb#KeyNone,        kb#KeyNone         ' 0x28
    word    $1B,               $1B,               kb#KeyNone,        kb#KeyNone         ' 0x29
    word    $08,               $08,               kb#KeyNone,        kb#KeyNone         ' 0x2A
    word    $09,               $09,               kb#KeyNone,        kb#KeyNone         ' 0x2B
    word    " ",               " ",               kb#KeyNone,        kb#KeyNone         ' 0x2C
    word    "'",               "?",               kb#KeyNone,        kb#KeyNone         ' 0x2D
    word    $8D,               "^",               $7E,               kb#KeyNone         ' 0x2E
    word    $8A,               $82,               "[",               "{"                ' 0x2F
    word    "+",               "*",               "]",               "}"                ' 0x30
    word    $97,               $15,               kb#KeyNone,        kb#KeyNone         ' 0x31
    word    $A3,               $15,               kb#KeyNone,        kb#KeyNone         ' 0x32
    word    $95,               $87,               "@",               kb#KeyNone         ' 0x33
    word    $85,               $F8,               "#",               kb#KeyNone         ' 0x34
    word    "\",               "|",               kb#KeyNone,        kb#KeyNone         ' 0x35
    word    ",",               ";",               kb#KeyNone,        kb#KeyNone         ' 0x36
    word    ".",               ":",               kb#KeyNone,        kb#KeyNone         ' 0x37
    word    "-",               "_",               kb#KeyNone,        kb#KeyNone         ' 0x38
    word    kb#KeyCapsLock,    kb#KeyCapsLock,    kb#KeyNone,        kb#KeyNone         ' 0x39
    word    kb#KeyF1,          kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x3A
    word    kb#KeyF2,          kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x3B
    word    kb#KeyF3,          kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x3C
    word    kb#KeyF4,          kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x3D
    word    kb#KeyF5,          kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x3E
    word    kb#KeyF6,          kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x3F
    word    kb#KeyF7,          kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x40
    word    kb#KeyF8,          kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x41
    word    kb#KeyF9,          kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x42
    word    kb#KeyF10,         kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x43
    word    kb#KeyF11,         kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x44
    word    kb#KeyF12,         kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x45
    word    kb#KeyPrintScreen, kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x46
    word    kb#KeyScrollLock,  kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x47
    word    kb#KeyPause,       kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x48
    word    kb#KeyInsert,      kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x49
    word    kb#KeyHome,        kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x4A
    word    kb#KeyPageUp,      kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x4B
    word    kb#KeyDelete,      kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x4C
    word    kb#KeyEnd,         kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x4D
    word    kb#KeyPageDown,    kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x4E
    word    kb#KeyRight,       kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x4F
    word    kb#KeyLeft,        kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x50
    word    kb#KeyDown,        kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x51
    word    kb#KeyUp,          kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x52
    word    kb#KeyNumLock,     kb#KeyNumLock,     kb#KeyNone,        kb#KeyNone         ' 0x53
    word    kb#KeyKP_Divide,   kb#KeyKP_Divide,   kb#KeyNone,        kb#KeyNone         ' 0x54
    word    kb#KeyKP_Multiply, kb#KeyKP_Multiply, kb#KeyNone,        kb#KeyNone         ' 0x55
    word    kb#KeyKP_Subtract, kb#KeyKP_Subtract, kb#KeyNone,        kb#KeyNone         ' 0x56
    word    kb#KeyKP_Add,      kb#KeyKP_Add,      kb#KeyNone,        kb#KeyNone         ' 0x57
    word    kb#KeyKP_Enter,    kb#KeyKP_Enter,    kb#KeyNone,        kb#KeyNone         ' 0x58
    word    kb#KeyEnd,         kb#KeyKP_1,        kb#KeyNone,        kb#KeyNone         ' 0x59
    word    kb#KeyDown,        kb#KeyKP_2,        kb#KeyNone,        kb#KeyNone         ' 0x5A
    word    kb#KeyPageDown,    kb#KeyKP_3,        kb#KeyNone,        kb#KeyNone         ' 0x5B
    word    kb#KeyLeft,        kb#KeyKP_4,        kb#KeyNone,        kb#KeyNone         ' 0x5C
    word    kb#KeyKP_Center,   kb#KeyKP_5,        kb#KeyNone,        kb#KeyNone         ' 0x5D
    word    kb#KeyRight,       kb#KeyKP_6,        kb#KeyNone,        kb#KeyNone         ' 0x5E
    word    kb#KeyHome,        kb#KeyKP_7,        kb#KeyNone,        kb#KeyNone         ' 0x5F
    word    kb#KeyUp,          kb#KeyKP_8,        kb#KeyNone,        kb#KeyNone         ' 0x60
    word    kb#KeyPageUp,      kb#KeyKP_9,        kb#KeyNone,        kb#KeyNone         ' 0x61
    word    kb#KeyInsert,      kb#KeyKP_0,        kb#KeyNone,        kb#KeyNone         ' 0x62
    word    kb#KeyDelete,      kb#KeyKP_Period,   kb#KeyNone,        kb#KeyNone         ' 0x63
    word    "<",               ">",               kb#KeyNone,        kb#KeyNone         ' 0x64
    word    kb#KeyApplication, kb#KeyApplication, kb#KeyNone,        kb#KeyNone         ' 0x65
    word    kb#KeyNone,        kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x66
    word    kb#KeyNone,        kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x67
    word    kb#KeyNone,        kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x68
    word    kb#KeyNone,        kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x69
    word    kb#KeyNone,        kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x6A
    word    kb#KeyNone,        kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x6B
    word    kb#KeyNone,        kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x6C
    word    kb#KeyNone,        kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x6D
    word    kb#KeyNone,        kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x6E
    word    kb#KeyNone,        kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x6F
    word    kb#KeyNone,        kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x70
    word    kb#KeyNone,        kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x71
    word    kb#KeyNone,        kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x72
    word    kb#KeyNone,        kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x73
    word    kb#KeyNone,        kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x74
    word    kb#KeyNone,        kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x75
    word    kb#KeyNone,        kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x76
    word    kb#KeyNone,        kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x77
    word    kb#KeyNone,        kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x78
    word    kb#KeyNone,        kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x79
    word    kb#KeyNone,        kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x7A
    word    kb#KeyNone,        kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x7B
    word    kb#KeyNone,        kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x7C
    word    kb#KeyNone,        kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x7D
    word    kb#KeyNone,        kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x7E
    word    kb#KeyNone,        kb#KeyNone,        kb#KeyNone,        kb#KeyNone         ' 0x7F

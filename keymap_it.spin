CON
    KeyNone = 0

    #$100
    KeySpace
    KeyEscape
    KeyBackspace
    KeyTabulator
    KeyReturn
    KeyInsert
    KeyHome
    KeyPageUp
    KeyDelete
    KeyEnd
    KeyPageDown
    KeyUp
    KeyDown
    KeyLeft
    KeyRight
    KeyF1
    KeyF2
    KeyF3
    KeyF4
    KeyF5
    KeyF6
    KeyF7
    KeyF8
    KeyF9
    KeyF10
    KeyF11
    KeyF12
    KeyApplication
    KeyCapsLock
    KeyPrintScreen
    KeyScrollLock
    KeyPause
    KeyNumLock
    KeyKP_Divide
    KeyKP_Multiply
    KeyKP_Subtract
    KeyKP_Add
    KeyKP_Enter
    KeyKP_1
    KeyKP_2
    KeyKP_3
    KeyKP_4
    KeyKP_5
    KeyKP_6
    KeyKP_7
    KeyKP_8
    KeyKP_9
    KeyKP_0
    KeyKP_Center
    KeyKP_Comma
    KeyKP_Period
    KeyMaxCode

PUB null
'' This is not a top level object.

PUB get_map
    return @keymap

PUB map(k, mod) | i
    return WORD[@keymap][k * 4 + mod]

DAT

keymap
    word    KeyNone,        KeyNone,        KeyNone,    KeyNone   ' 0x00
    word    KeyNone,        KeyNone,        KeyNone,    KeyNone   ' 0x01
    word    KeyNone,        KeyNone,        KeyNone,    KeyNone   ' 0x02
    word    KeyNone,        KeyNone,        KeyNone,    KeyNone   ' 0x03
    word    "a",            "A",            KeyNone,    KeyNone   ' 0x04
    word    "b",            "B",            KeyNone,    KeyNone   ' 0x05
    word    "c",            "C",            KeyNone,    KeyNone   ' 0x06
    word    "d",            "D",            KeyNone,    KeyNone   ' 0x07
    word    "e",            "E",            $80,        $80       ' 0x08
    word    "f",            "F",            KeyNone,    KeyNone   ' 0x09
    word    "g",            "G",            KeyNone,    KeyNone   ' 0x0A
    word    "h",            "H",            KeyNone,    KeyNone   ' 0x0B
    word    "i",            "I",            KeyNone,    KeyNone   ' 0x0C
    word    "j",            "J",            KeyNone,    KeyNone   ' 0x0D
    word    "k",            "K",            KeyNone,    KeyNone   ' 0x0E
    word    "l",            "L",            KeyNone,    KeyNone   ' 0x0F
    word    "m",            "M",            KeyNone,    KeyNone   ' 0x10
    word    "n",            "N",            KeyNone,    KeyNone   ' 0x11
    word    "o",            "O",            KeyNone,    KeyNone   ' 0x12
    word    "p",            "P",            KeyNone,    KeyNone   ' 0x13
    word    "q",            "Q",            KeyNone,    KeyNone   ' 0x14
    word    "r",            "R",            KeyNone,    KeyNone   ' 0x15
    word    "s",            "S",            KeyNone,    KeyNone   ' 0x16
    word    "t",            "T",            KeyNone,    KeyNone   ' 0x17
    word    "u",            "U",            KeyNone,    KeyNone   ' 0x18
    word    "v",            "V",            KeyNone,    KeyNone   ' 0x19
    word    "w",            "W",            KeyNone,    KeyNone   ' 0x1A
    word    "x",            "X",            KeyNone,    KeyNone   ' 0x1B
    word    "y",            "Y",            KeyNone,    KeyNone   ' 0x1C
    word    "z",            "Z",            KeyNone,    KeyNone   ' 0x1D
    word    "1",            "!",            KeyNone,    KeyNone   ' 0x1E
    word    "2",            $22,            KeyNone,    KeyNone   ' 0x1F
    word    "3",            $9C,            KeyNone,    KeyNone   ' 0x20
    word    "4",            "$",            KeyNone,    KeyNone   ' 0x21
    word    "5",            "%",            $80,        $80       ' 0x22
    word    "6",            "&",            KeyNone,    KeyNone   ' 0x23
    word    "7",            "/",            KeyNone,    KeyNone   ' 0x24
    word    "8",            "(",            KeyNone,    KeyNone   ' 0x25
    word    "9",            ")",            KeyNone,    KeyNone   ' 0x26
    word    "0",            "=",            KeyNone,    KeyNone   ' 0x27
    word    $0D,            $0D,            KeyNone,    KeyNone   ' 0x28 Return
    word    $1B,            $1B,            KeyNone,    KeyNone   ' 0x29 ESCape
    word    $08,            $08,            KeyNone,    KeyNone   ' 0x2A Backspace
    word    $09,            $09,            KeyNone,    KeyNone   ' 0x2B TAB
    word    " ",            " ",            KeyNone,    KeyNone   ' 0x2C Space
    word    "'",            "?",            KeyNone,    KeyNone   ' 0x2D
    word    $8D,            "^",            KeyNone,    KeyNone   ' 0x2E
    word    $8A,            $82,            "[",        "{"       ' 0x2F
    word    "+",            "*",            "]",        "}"       ' 0x30
    word    $97,            $F5,            KeyNone,    KeyNone   ' 0x31
    word    $A3,            $F5,            KeyNone,    KeyNone   ' 0x32
    word    $95,            $87,            "@",        KeyNone   ' 0x33
    word    $85,            $F8,            "#",        KeyNone   ' 0x34
    word    "\",            "|",            KeyNone,    KeyNone   ' 0x35
    word    ",",            ";",            KeyNone,    KeyNone   ' 0x36
    word    ".",            ":",            KeyNone,    KeyNone   ' 0x37
    word    "-",            "_",            KeyNone,    KeyNone   ' 0x38
    word    KeyCapsLock,    KeyCapsLock,    KeyNone,    KeyNone   ' 0x39
    word    KeyF1,          KeyNone,        KeyNone,    KeyNone   ' 0x3A
    word    KeyF2,          KeyNone,        KeyNone,    KeyNone   ' 0x3B
    word    KeyF3,          KeyNone,        KeyNone,    KeyNone   ' 0x3C
    word    KeyF4,          KeyNone,        KeyNone,    KeyNone   ' 0x3D
    word    KeyF5,          KeyNone,        KeyNone,    KeyNone   ' 0x3E
    word    KeyF6,          KeyNone,        KeyNone,    KeyNone   ' 0x3F
    word    KeyF7,          KeyNone,        KeyNone,    KeyNone   ' 0x40
    word    KeyF8,          KeyNone,        KeyNone,    KeyNone   ' 0x41
    word    KeyF9,          KeyNone,        KeyNone,    KeyNone   ' 0x42
    word    KeyF10,         KeyNone,        KeyNone,    KeyNone   ' 0x43
    word    KeyF11,         KeyNone,        KeyNone,    KeyNone   ' 0x44
    word    KeyF12,         KeyNone,        KeyNone,    KeyNone   ' 0x45
    word    KeyPrintScreen, KeyNone,        KeyNone,    KeyNone   ' 0x46
    word    KeyScrollLock,  KeyNone,        KeyNone,    KeyNone   ' 0x47
    word    KeyPause,       KeyNone,        KeyNone,    KeyNone   ' 0x48
    word    KeyInsert,      KeyNone,        KeyNone,    KeyNone   ' 0x49
    word    KeyHome,        KeyNone,        KeyNone,    KeyNone   ' 0x4A
    word    KeyPageUp,      KeyNone,        KeyNone,    KeyNone   ' 0x4B
    word    KeyDelete,      KeyNone,        KeyNone,    KeyNone   ' 0x4C
    word    KeyEnd,         KeyNone,        KeyNone,    KeyNone   ' 0x4D
    word    KeyPageDown,    KeyNone,        KeyNone,    KeyNone   ' 0x4E
    word    KeyRight,       KeyNone,        KeyNone,    KeyNone   ' 0x4F
    word    KeyLeft,        KeyNone,        KeyNone,    KeyNone   ' 0x50
    word    KeyDown,        KeyNone,        KeyNone,    KeyNone   ' 0x51
    word    KeyUp,          KeyNone,        KeyNone,    KeyNone   ' 0x52
    word    KeyNumLock,     KeyNumLock,     KeyNone,    KeyNone   ' 0x53
    word    KeyKP_Divide,   KeyKP_Divide,   KeyNone,    KeyNone   ' 0x54
    word    KeyKP_Multiply, KeyKP_Multiply, KeyNone,    KeyNone   ' 0x55
    word    KeyKP_Subtract, KeyKP_Subtract, KeyNone,    KeyNone   ' 0x56
    word    KeyKP_Add,      KeyKP_Add,      KeyNone,    KeyNone   ' 0x57
    word    KeyKP_Enter,    KeyKP_Enter,    KeyNone,    KeyNone   ' 0x58
    word    KeyEnd,         KeyKP_1,        KeyNone,    KeyNone   ' 0x59
    word    KeyDown,        KeyKP_2,        KeyNone,    KeyNone   ' 0x5A
    word    KeyPageDown,    KeyKP_3,        KeyNone,    KeyNone   ' 0x5B
    word    KeyLeft,        KeyKP_4,        KeyNone,    KeyNone   ' 0x5C
    word    KeyKP_Center,   KeyKP_5,        KeyNone,    KeyNone   ' 0x5D
    word    KeyRight,       KeyKP_6,        KeyNone,    KeyNone   ' 0x5E
    word    KeyHome,        KeyKP_7,        KeyNone,    KeyNone   ' 0x5F
    word    KeyUp,          KeyKP_8,        KeyNone,    KeyNone   ' 0x60
    word    KeyPageUp,      KeyKP_9,        KeyNone,    KeyNone   ' 0x61
    word    KeyInsert,      KeyKP_0,        KeyNone,    KeyNone   ' 0x62
    word    KeyDelete,      KeyKP_Period,   KeyNone,    KeyNone   ' 0x63
    word    "<",            ">",            KeyNone,    KeyNone   ' 0x64
    word    KeyApplication, KeyApplication, KeyNone,    KeyNone   ' 0x65
    word    KeyNone,        KeyNone,        KeyNone,    KeyNone   ' 0x66
    word    KeyNone,        KeyNone,        KeyNone,    KeyNone   ' 0x67
    word    KeyNone,        KeyNone,        KeyNone,    KeyNone   ' 0x68
    word    KeyNone,        KeyNone,        KeyNone,    KeyNone   ' 0x69
    word    KeyNone,        KeyNone,        KeyNone,    KeyNone   ' 0x6A
    word    KeyNone,        KeyNone,        KeyNone,    KeyNone   ' 0x6B
    word    KeyNone,        KeyNone,        KeyNone,    KeyNone   ' 0x6C
    word    KeyNone,        KeyNone,        KeyNone,    KeyNone   ' 0x6D
    word    KeyNone,        KeyNone,        KeyNone,    KeyNone   ' 0x6E
    word    KeyNone,        KeyNone,        KeyNone,    KeyNone   ' 0x6F
    word    KeyNone,        KeyNone,        KeyNone,    KeyNone   ' 0x70
    word    KeyNone,        KeyNone,        KeyNone,    KeyNone   ' 0x71
    word    KeyNone,        KeyNone,        KeyNone,    KeyNone   ' 0x72
    word    KeyNone,        KeyNone,        KeyNone,    KeyNone   ' 0x73
    word    KeyNone,        KeyNone,        KeyNone,    KeyNone   ' 0x74
    word    KeyNone,        KeyNone,        KeyNone,    KeyNone   ' 0x75
    word    KeyNone,        KeyNone,        KeyNone,    KeyNone   ' 0x76
    word    KeyNone,        KeyNone,        KeyNone,    KeyNone   ' 0x77
    word    KeyNone,        KeyNone,        KeyNone,    KeyNone   ' 0x78
    word    KeyNone,        KeyNone,        KeyNone,    KeyNone   ' 0x79
    word    KeyNone,        KeyNone,        KeyNone,    KeyNone   ' 0x7A
    word    KeyNone,        KeyNone,        KeyNone,    KeyNone   ' 0x7B
    word    KeyNone,        KeyNone,        KeyNone,    KeyNone   ' 0x7C
    word    KeyNone,        KeyNone,        KeyNone,    KeyNone   ' 0x7D
    word    KeyNone,        KeyNone,        KeyNone,    KeyNone   ' 0x7E
    word    KeyNone,        KeyNone,        KeyNone,    KeyNone   ' 0x7F

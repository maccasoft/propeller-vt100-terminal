{{
    ANSI / VT-100 Terminal Emulator
    Copyright (c) 2017 Marco Maccaferri and others

    TERMS OF USE: MIT License
}}

CON

    _XINFREQ = 5_000_000
    _CLKMODE = XTAL1 + PLL16X

    columns  = driver#res_x / 9
    rows     = driver#res_y / font#height
    bcnt     = columns * rows

    rows_raw = (driver#res_y + font#height - 1) / font#height
    bcnt_raw = columns * rows_raw

    vgrp     = 2                                          ' video pin group
    mode     = 0                                          ' 0: FG on/off, 1: FG :==: BG

    video    = (vgrp << 9 | mode << 8 | %%333_0) << 21

    CURSOR_ON    = driver#CURSOR_ON
    CURSOR_OFF   = driver#CURSOR_OFF
    CURSOR_ULINE = driver#CURSOR_ULINE
    CURSOR_BLOCK = driver#CURSOR_BLOCK
    CURSOR_FLASH = driver#CURSOR_FLASH
    CURSOR_SOLID = driver#CURSOR_SOLID

    CURSOR_MASK  = driver#CURSOR_MASK

    #0, CM, CX, CY

VAR

    long  scrn[bcnt_raw / 2]                              ' screen buffer
    long  link[driver#res_m]                              ' mailbox

    long  txt_cursor                                      ' text cursor
    long  txt_attr                                        ' text attribute

    long  ansi_argc
    long  ansi_args[8]
    long  ansi_cursor_save

    long  usb_stack[128]
    byte  usb_buf[64]
    byte  usb_report[8]

OBJ

    hc     : "usb-fs-host"
    ser    : "com.serial"
    debug  : "com.serial.terminal"
    driver : "waitvid.80x25.driver"
    font   : "generic8x16-2font"
    'keymap : "keymap_us"
    keymap : "keymap_it"
    'keymap : "keymap_uk"

PUB start | c, x, y

    debug.Start(115200)
    ser.StartRxTx(8, 9, 0, 115200)

    txt_attr := $20_70
    wordfill(@scrn, txt_attr, bcnt)
    txt_cursor.byte[CX] := 0
    txt_cursor.byte[CY] := 0

    link{0} := video | @scrn{0}
    link[1] := font#height << 24 | font.addr
    link[2] := @txt_cursor
    driver.init(-1, @link{0})

    setCursor(CURSOR_ON|CURSOR_BLOCK|CURSOR_FLASH)

    cognew(start_usb, @usb_stack)

{
    repeat y from 0 to 15
        repeat x from 0 to 7
            txt_attr := (y << 4) | (x << 1)
            printText(string($80, $80, $80, $80, $80))
        txt_cursor.byte[CX] := 0
        txt_cursor.byte[CY]++

    txt_attr := $20_F0
    i := 0
    repeat y from 0 to 7
        repeat x from 0 to 31
            printChar(i++)
        txt_cursor.byte[CX] := 0
        txt_cursor.byte[CY]++
    txt_cursor.byte[CY]++
}

    repeat
        c := ser.rxCheck
        if c == -1
            c := debug.rxCheck
            if c <> -1
                ser.char(c)
            next

        case c
            $08:
                if txt_cursor.byte[CX] > 0
                    txt_cursor.byte[CX]--
            $09:
                x := txt_cursor.byte[CX]
                y := txt_cursor.byte[CY]

                x := ((x / 8) + 1) * 8
                ifnot x //= columns                     ' wrap right
                    if y < constant(rows - 1)
                        y++
                    else
                        scroll

                txt_cursor.byte[CX] := x
                txt_cursor.byte[CY] := y

            $0A:
                if txt_cursor.byte[CY] < constant(rows - 1)
                    txt_cursor.byte[CY]++
                else
                    scroll
            $0C:
                txt_attr.byte[1] := $20
                wordfill(@scrn, txt_attr, bcnt)
                txt_cursor.byte[CX] := 0
                txt_cursor.byte[CY] := 0
            $0D:
                txt_cursor.byte[CX] := 0
            $1B:
                c := ser.charIn
                if c == "["
                    decodeVT100
            other:
                x := txt_cursor.byte[CX] + 1
                y := txt_cursor.byte[CY]

                txt_attr.byte[1] := c
                scrn.word[bcnt_raw - y * columns - x] := txt_attr
                ifnot x //= columns                     ' wrap right
                    if y < constant(rows - 1)
                        y++
                    else
                        scroll

                txt_cursor.byte[CX] := x
                txt_cursor.byte[CY] := y

PRI decodeVT100 | c, i, x, y

    ansi_argc := 0
    ansi_args[ansi_argc] := 0

    repeat
        c := ser.charIn
        case c
            "0".."9":
                ansi_args[ansi_argc] := ansi_args[ansi_argc] * 10 + (c - $30)
            ";":
                ansi_argc++
                ansi_args[ansi_argc] := 0
            "A":
                if txt_cursor.byte[CY] > 0
                    txt_cursor.byte[CY]--
                return
            "B":
                if txt_cursor.byte[CY] < constant(rows - 1)
                    txt_cursor.byte[CY]++
                return
            "C":
                if txt_cursor.byte[CX] < constant(columns - 1)
                    txt_cursor.byte[CX]++
                return
            "D":
                if txt_cursor.byte[CX] > 0
                    txt_cursor.byte[CX]--
                return
            "J":
                if ansi_args[0] == 2
                    wordfill(@scrn, txt_attr, bcnt)
                return
            "K":
                x := txt_cursor.byte[CX]
                y := txt_cursor.byte[CY]
                txt_attr.byte[1] := $20
                if ansi_args[0] == 1
                    repeat txt_cursor.byte[CX]
                        scrn.word[bcnt_raw - y * columns - --x] := txt_attr
                else
                    repeat constant(columns - 1) - txt_cursor.byte[CX]
                        scrn.word[bcnt_raw - y * columns - ++x] := txt_attr
                return
            "f":
            "H":
                if ansi_args[0] <> 0
                    txt_cursor.byte[CY] := (ansi_args[0] - 1) // rows
                else
                    txt_cursor.byte[CY] := 0
                if ansi_argc => 1
                    txt_cursor.byte[CX] := (ansi_args[1] - 1) // columns
                else
                    txt_cursor.byte[CX] := 0
                return
            "m":
                if ansi_argc => 2 and ansi_args[1] == 5
                    if ansi_args[0] == 38
                        txt_attr := (txt_attr & $0F) | (ansi_args[2] << 4)
                        return
                    if ansi_args[0] == 48
                        txt_attr := (txt_attr & $F0) | ansi_args[2]
                        txt_attr &= $FE
                        return

                repeat i from 0 to ansi_argc
                    if ansi_args[i] == 0
                        txt_attr &= $7F
                    elseif ansi_args[i] == 1
                        txt_attr |= $80
                    elseif ansi_args[i] => 30 and ansi_args[i] =< 37
                        txt_attr := (txt_attr & $8F) | ((ansi_args[i] - 30) << 4)
                    elseif ansi_args[i] => 40 and ansi_args[i] =< 47
                        txt_attr := (txt_attr & $F1) | ((ansi_args[i] - 40) << 1)
                return
            "s":
                ansi_cursor_save := txt_cursor
            "u":
                txt_cursor := ansi_cursor_save
            other:
                return

PUB start_usb | retval, ifd, epd

    debug.str(string(debug#CS, "USB Started", debug#NL, debug#LF))

    repeat
        if showError(\hc.Enumerate, string("Can't enumerate device"))
            waitcnt(CNT + CLKFREQ)
            next

        debug.str(string("Found device "))
        debug.hex(hc.VendorID, 4)
        debug.char(":")
        debug.hex(hc.ProductID, 4)
        debug.str(string(debug#NL, debug#LF))

        if showError(\hc.Configure, string("Error configuring device"))
            waitcnt(CNT + CLKFREQ)
            next

        if not (ifd := hc.FindInterface(3))
            debug.str(string("Device has no HID interfaces", debug#NL, debug#LF))
            waitcnt(CNT + CLKFREQ)
            next

        ' First endpoint on the first HID interface
        epd := hc.NextEndpoint(ifd)

        repeat while hc.GetPortConnection <> hc#PORTC_NO_DEVICE
            retval := \hc.InterruptRead(epd, @usb_buf, 64)

            if retval == hc#E_TIMEOUT
                ' No data available. Try again later.

            elseif not showError(retval, string("Read Error"))
                ' Successful transfer
                debug.char("[")
                debug.dec(retval)
                debug.str(string(" bytes] "))
                hexDump(@usb_buf, retval)
                decode(@usb_buf)
                debug.str(string(debug#NL, debug#LF))

        waitcnt(CNT + CLKFREQ)

PRI decode(buffer) | i, c, k, mod, ptr

    usb_report[0] := BYTE[buffer][0]
    usb_report[1] := BYTE[buffer][1]

    if (usb_report[0] & %00100010) <> 0         ' SHIFT
        if (usb_report[0] & %01000000) <> 0     ' SHIFT+ALT GR ?
            mod := 3
        else
            mod := 1
    elseif (usb_report[0] & %01000000) <> 0     ' ALT GR
        mod := 2
    else
        mod := 0

    debug.char("[")

    repeat i from 2 to 7
        k := BYTE[buffer][i]
        if k <> 0 and lookdown(k : usb_report[2], usb_report[3], usb_report[4], usb_report[5], usb_report[6], usb_report[7]) == 0
            c := keymap.map(k, mod)
            if c => 0 and c =< $FF
                ser.char(c)
                debug.hex(c, 2)
            elseif c => $100 and c < keymap#KeyMaxCode
                debug.dec(c - $100)
                ptr := WORD[@strTable][c - $100]
                repeat strsize(ptr)
                    ser.char(byte[ptr])
                    debug.char(" ")
                    debug.hex(byte[ptr], 2)
                    ptr++
        usb_report[i] := k

    debug.char("]")

PRI decodeDebug(buffer)

    hexDump(buffer, 8)
    debug.char(debug#NL)

    decode(buffer)

    debug.char(debug#NL)


PRI hexDump(buffer, len)
    repeat while len--
        debug.hex(BYTE[buffer++], 2)
        debug.char(" ")

PRI showError(error, message) : bool
    if error < 0
        debug.str(message)
        debug.str(string(" (Error "))
        debug.dec(error)
        debug.str(string(")", debug#NL))
        return 1
    return 0

PRI printText(s)

  repeat strsize(s)
      printChar(byte[s++])

PRI printChar(c) | x, y

  x := txt_cursor.byte[CX] + 1
  y := txt_cursor.byte[CY]

  txt_attr.byte[1] := c
  scrn.word[bcnt_raw - y * columns - x] := txt_attr
  ifnot x //= columns                                   ' wrap right
    if y < constant(rows - 1)
      y++
    else
      scroll

  txt_cursor.byte[CX] := x
  txt_cursor.byte[CY] := y

PRI setCursor(setup)

  txt_cursor.byte{CM} := (txt_cursor.byte{CM} & constant(!CURSOR_MASK)) | setup

PRI scroll

    txt_attr.byte[1] := $20
    wordmove(@scrn.word[columns], @scrn.word[0], constant(bcnt - columns))
    wordfill(@scrn.word[0], txt_attr, columns)

DAT

strTable
                    word    @strKeySpace
                    word    @strKeyEscape
                    word    @strKeyBackspace
                    word    @strKeyTabulator
                    word    @strKeyReturn
                    word    @strKeyInsert
                    word    @strKeyHome
                    word    @strKeyPageUp
                    word    @strKeyDelete
                    word    @strKeyEnd
                    word    @strKeyPageDown
                    word    @strKeyUp
                    word    @strKeyDown
                    word    @strKeyLeft
                    word    @strKeyRight
                    word    @strKeyF1
                    word    @strKeyF2
                    word    @strKeyF3
                    word    @strKeyF4
                    word    @strKeyF5
                    word    @strKeyF6
                    word    @strKeyF7
                    word    @strKeyF8
                    word    @strKeyF9
                    word    @strKeyF10
                    word    @strKeyF11
                    word    @strKeyF12
                    word    @strKeyApplication
                    word    @strKeyCapsLock
                    word    @strKeyPrintScreen
                    word    @strKeyScrollLock
                    word    @strKeyPause
                    word    @strKeyNumLock
                    word    @strKeyKP_Divide
                    word    @strKeyKP_Multiply
                    word    @strKeyKP_Subtract
                    word    @strKeyKP_Add
                    word    @strKeyKP_Enter
                    word    @strKeyKP_1
                    word    @strKeyKP_2
                    word    @strKeyKP_3
                    word    @strKeyKP_4
                    word    @strKeyKP_5
                    word    @strKeyKP_6
                    word    @strKeyKP_7
                    word    @strKeyKP_8
                    word    @strKeyKP_9
                    word    @strKeyKP_0
                    word    @strKeyKP_Center
                    word    @strKeyKP_Comma
                    word    @strKeyKP_Period

strKeySpace         byte    " ", 0
strKeyEscape        byte    $1B, 0
strKeyBackspace     byte    $08, 0
strKeyTabulator     byte    $09, 0
strKeyReturn        byte    $0D, 0
strKeyInsert        byte    0
strKeyHome          byte    $1B, "[H", 0
strKeyPageUp        byte    0
strKeyDelete        byte    $7F, 0
strKeyEnd           byte    $1B, "[K", 0
strKeyPageDown      byte    0
strKeyUp            byte    $1B, "[A", 0
strKeyDown          byte    $1B, "[B", 0
strKeyLeft          byte    $1B, "[D", 0
strKeyRight         byte    $1B, "[C", 0
strKeyF1            byte    $1B, "OP", 0
strKeyF2            byte    $1B, "OQ", 0
strKeyF3            byte    $1B, "OR", 0
strKeyF4            byte    $1B, "OS", 0
strKeyF5            byte    $1B, "OT", 0
strKeyF6            byte    $1B, "OU", 0
strKeyF7            byte    $1B, "OV", 0
strKeyF8            byte    $1B, "OW", 0
strKeyF9            byte    $1B, "OX", 0
strKeyF10           byte    $1B, "OY", 0
strKeyF11           byte    $1B, "OZ", 0
strKeyF12           byte    0
strKeyApplication   byte    0
strKeyCapsLock      byte    0
strKeyPrintScreen   byte    0
strKeyScrollLock    byte    0
strKeyPause         byte    0
strKeyNumLock       byte    0
strKeyKP_Divide     byte    "/", 0
strKeyKP_Multiply   byte    "*", 0
strKeyKP_Subtract   byte    "-", 0
strKeyKP_Add        byte    "+", 0
strKeyKP_Enter      byte    $0D, 0
strKeyKP_1          byte    "1", 0
strKeyKP_2          byte    "2", 0
strKeyKP_3          byte    "3", 0
strKeyKP_4          byte    "4", 0
strKeyKP_5          byte    "5", 0
strKeyKP_6          byte    "6", 0
strKeyKP_7          byte    "7", 0
strKeyKP_8          byte    "8", 0
strKeyKP_9          byte    "9", 0
strKeyKP_0          byte    "0", 0
strKeyKP_Center     byte    0
strKeyKP_Comma      byte    ",", 0
strKeyKP_Period     byte    ".", 0

{{

 TERMS OF USE: MIT License

 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
 associated documentation files (the "Software"), to deal in the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
 following conditions:

 The above copyright notice and this permission notice shall be included in all copies or substantial
 portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
 LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

}}

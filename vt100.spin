{{
    ANSI / VT-100 Terminal Emulator
    Copyright (c) 2017-18 Marco Maccaferri and others

    TERMS OF USE: MIT License
}}

CON

    _XINFREQ = 5_000_000
    _CLKMODE = XTAL1 + PLL16X

    columns  = vga#txt_columns
    rows     = vga#txt_rows
    bcnt     = columns * rows

    vgrp     = 2                                          ' video pin group
    mode     = 0                                          ' 0: FG on/off, 1: FG :==: BG

    video    = (vgrp << 9 | mode << 8 | %%333_0) << 21

    CURSOR_ON    = vga#CURSOR_ON
    CURSOR_OFF   = vga#CURSOR_OFF
    CURSOR_ULINE = vga#CURSOR_ULINE
    CURSOR_BLOCK = vga#CURSOR_BLOCK
    CURSOR_FLASH = vga#CURSOR_FLASH
    CURSOR_SOLID = vga#CURSOR_SOLID

    CURSOR_MASK  = vga#CURSOR_MASK

    #0, CM, CX, CY

    ' USB HID

    REQUEST_OUT = 0
    REQUEST_CLASS = $20
    REQUEST_TO_INTERFACE = 1

    REQ_SET_REPORT = REQUEST_OUT | REQUEST_CLASS | REQUEST_TO_INTERFACE | $0900

    REPORT_TYPE_OUTPUT = $0200

    LED_NUM_LOCK = $01
    LED_CAPS_LOCK = $02
    LED_SCROLL_LOCK = $04

    REPEAT_DELAY = 400
    REPEAT_RATE = 80

    BELL_PINA = 14
    BELL_PINB = 15
    BELL_FREQ = 800
    BELL_MS   = 200

VAR

    long  scrn[bcnt / 2]            ' screen buffer
    long  link[vga#res_m]           ' mailbox

    long  cursor                    ' text cursor

    long  usb_stack[128]
    byte  usb_buf[64]
    byte  usb_report[8]
    byte  usb_led

    long  kb_last
    long  kb_timer
    long  kb_mod
    long  kb_str_table

OBJ

    hc     : "usb-fs-host"
    ser    : "com.serial"
    debug  : "com.serial.terminal"
    vga    : "waitvid.80x25.driver"
    font   : "generic8x16-2font"
    kb     : "keyboard"
#ifdef KEYMAP_IT
    keymap : "keymap_it"
#endif
#ifdef KEYMAP_UK
    keymap : "keymap_uk"
#endif
#ifdef KEYMAP_US
    keymap : "keymap_us"
#endif
#ifdef KEYMAP_FR
    keymap : "keymap_fr"
#endif
#ifdef KEYMAP_DE
    keymap : "keymap_de"
#endif
#ifdef KEYMAP_NO
    keymap : "keymap_no"
#endif

PUB start | temp

    ser.StartRxTx(8, 9, 0, 115200)
    debug.StartRxTx(31, 30, 0, 115200)

    wordfill(@scrn, $20_70, bcnt)
    cursor.byte[CX] := 0
    cursor.byte[CY] := 0
    cursor.byte{CM} := (cursor.byte{CM} & constant(!CURSOR_MASK)) | constant(CURSOR_ON | CURSOR_BLOCK | CURSOR_FLASH)

    link{0} := video | @scrn{0}
    link[1] := font#height << 24 | font.addr
    link[2] := @cursor
    vga.init(-1, @link{0})

    cognew(usb_hid, @usb_stack)

    temp := ser.GetMailbox
    rx_head := temp
    rx_tail := temp + 4
    rx_buffer := LONG[temp][8]
    tx_head := temp + 8
    tx_tail := temp + 12
    tx_buffer := rx_buffer + ser#BUFFER_LENGTH

    temp := debug.GetMailbox
    aux_rx_head := temp
    aux_rx_tail := temp + 4
    aux_rx_buffer := LONG[temp][8]

    txt_cursor := @cursor
    txt_scrn := @scrn + (bcnt << 1)

#ifdef CURSOR_KEY_APP
    kb_str_table := @strTableApp
#else
    kb_str_table := @strTable
#endif
    kb_str_table_ptr := @kb_str_table
    kb_str_table_1 := @strTable
    kb_str_table_2 := @strTableApp

    esc_overlay_par := OverlayParams(@_esc, @_esc_end)
    attr_overlay_par := OverlayParams(@_attr, @_attr_end)
    vt_overlay_par := OverlayParams(@_vt, @_vt_end)

    coginit(cogid, @entry, 0)

PRI OverlayParams (o_start, o_end) : params | len, hubend, cogend
    ' This code sets up the parameters for an overlay (in a format to increase overlay loading speed)
    len := o_end - o_start
    hubend := o_start + len - 1
    cogend := ((@overlay_start - @entry + len) / 4) - 1
    params := hubend << 16 + cogend


DAT

                    org     0

entry               mov     DIRA, bell_mask
                    jmp     #_bell

_loop               call    #charIn
                    cmp     ch, #$07 wz             ' bell
        if_z        jmp     #_bell
                    cmp     ch, #$08 wz             ' backspace
        if_z        jmp     #_bs
                    cmp     ch, #$09 wz             ' tab
        if_z        jmp     #_tab
                    cmp     ch, #$0A wz             ' line feed
        if_z        jmp     #_lf
                    cmp     ch, #$0C wz             ' form feed
        if_z        jmp     #_ff
                    cmp     ch, #$0D wz             ' carriage return
        if_z        jmp     #_cr
                    cmp     ch, #$1B wz             ' esc
        if_z        mov     overlay_par, esc_overlay_par
        if_z        jmp     #overlay_load

                    ' write ch to vga buffer

_print              cmpsub  x, #columns wc
        if_nc       jmp     #:l1
                    cmp     y, #rows-1 wc,wz
        if_c        add     y, #1
        if_nc       call    #scroll

:l1                 mov     t1, y                   ' t2 := y * 80
                    shl     t1, #4
                    mov     t2, t1
                    shl     t2, #2
                    add     t2, t1
                    add     t2, x                   ' t2 := t1 + x
                    shl     t2, #1

                    mov     t1, txt_scrn
                    sub     t1, t2
                    sub     t1, #2
                    mov     a, ch
                    shl     a, #8
                    or      a, txt_attr
                    wrword  a, t1

                    add     x, #1

_done               mov     t1, txt_cursor          ' updates cursor position
                    add     t1, #CX
                    mov     a,x
                    cmp     a, #columns wz,wc
        if_nc       mov     a, #columns-1
                    wrbyte  a, t1
                    add     t1, #1
                    wrbyte  y, t1
                    jmp     #_loop

_bell               mov     FRQA, bell_frq
                    mov     CTRA, bell_ctr
                    mov     a, CNT
                    add     a, bell_duration
                    waitcnt a, #0
                    mov     CTRA, #0
                    jmp     #_loop

_bs                 cmpsub  x, #1
                    jmp     #_done

_tab                cmpsub  x, #columns
                    andn    x, #7
                    add     x, #8
                    jmp     #_done

_lf                 cmp     y, #rows-1 wc,wz
        if_c        add     y, #1
        if_nc       call    #scroll
                    jmp     #_done

_ff                 mov     x, #0
                    mov     y, #0
_cls                mov     t1, #$20
                    shl     t1, #8
                    or      t1, txt_attr
                    mov     a, t1
                    shl     a, #16
                    or      a, t1
                    mov     t1, txt_scrn
                    sub     t1, #4
                    mov     t3, txt_bcnt
                    shr     t3, #1
:l1                 wrlong  a, t1
                    sub     t1, #4
                    djnz    t3, #:l1
                    jmp     #_done

_cr                 mov     x, #0
                    jmp     #_done

' resident code

charIn              rdlong  t1, rx_head
                    rdlong  t2, rx_tail
                    cmp     t1, t2 wz
        if_z        jmp     #charIn

                    mov     t1, rx_buffer
                    add     t1, t2
                    rdbyte  ch, t1
                    add     t2, #1
                    and     t2, #ser#BUFFER_MASK
                    wrlong  t2, rx_tail
charIn_ret          ret

scroll              mov     t1, txt_scrn
                    sub     t1, #4
                    mov     t2, t1
                    sub     t2, #columns << 1
                    mov     t3, txt_bcnt
                    sub     t3, #columns
                    shr     t3, #1
:l1                 rdlong  a, t2
                    sub     t2, #4
                    wrlong  a, t1
                    sub     t1, #4
                    djnz    t3, #:l1

                    mov     t2, #$20
                    shl     t2, #8
                    or      t2, txt_attr
                    mov     a, t2
                    shl     a, #16
                    or      a, t2
                    mov     t3, #columns >> 1
:l2                 wrlong  a, t1
                    sub     t1, #4
                    djnz    t3, #:l2

scroll_ret          ret

' initialised data and/or presets

incdst              long    1 << 9

rx_buffer           long    0
rx_head             long    0
rx_tail             long    0

tx_buffer           long    0
tx_head             long    0
tx_tail             long    0

aux_rx_buffer       long    0
aux_rx_head         long    0
aux_rx_tail         long    0

txt_cursor          long    0
txt_scrn            long    0
txt_bcnt            long    bcnt
txt_attr            long    $70
txt_cursor_s        long    0

bell_mask           long    (1 << BELL_PINA) | (1 << BELL_PINB)
bell_ctr            long    (%00100 << 26) | (BELL_PINB << 9) | BELL_PINA
bell_frq            long    trunc(53.6870912 * float(BELL_FREQ))
bell_duration       long    (80000000 / 1000) * BELL_MS

x                   long    0
y                   long    0

esc_overlay_par     long    0
attr_overlay_par    long    0
vt_overlay_par      long    0

' uninitialised data and/or temporaries

a                   long    0
ch                  long    0
ch_mod              long    0
t1                  long    0
t2                  long    0
t3                  long    0

argc                long    0
args                long    0[8]

' overlay loader

overlay_par         long    0-0

_0x400              long    $0000_0400
_djnz0              djnz    overlay_par, #_cp2

overlay_load        mov     overlay_start, _djnz0
                    movd    _cp2, overlay_par
                    sub     overlay_par, #1
                    movd    _cp1, overlay_par
                    shr     overlay_par, #16
_cp2                rdlong  0-0, overlay_par
                    sub     overlay_par, #7
                    sub     _cp2, _0x400
_cp1                rdlong  0-0, overlay_par
                    sub     _cp1, _0x400

overlay_start

                    fit     $1F0

                    org     overlay_start

_esc                mov     argc, #0
                    mov     args, #0
                    mov     args+1, #0
                    mov     ch_mod, #0

                    call    #charIn
                    cmp     ch, #$1B wz             ' esc (again, print it)
        if_z        jmp     #_print

                    cmp     ch, #"A" wz             ' VT-52 compatibility
        if_z        jmp     #_up
                    cmp     ch, #"B" wz
        if_z        jmp     #_down
                    cmp     ch, #"C" wz
        if_z        jmp     #_right
                    cmp     ch, #"D" wz
        if_z        jmp     #_left
                    cmp     ch, #"H" wz
        if_z        jmp     #_cup

                    cmp     ch, #"J" wz
        if_nz       cmp     ch, #"K" wz
        if_nz       cmp     ch, #"7" wz
        if_nz       cmp     ch, #"8" wz
        if_z        mov     overlay_par, vt_overlay_par
        if_z        jmp     #overlay_load

                    cmp     ch, #"[" wz
        if_nz       jmp     #_done

                    call    #charIn
                    cmp     ch, #"?" wz             ' check private prefix after "["
        if_nz       jmp     #:l2+1
                    mov     ch_mod, ch

:l2                 call    #charIn
                    cmp     ch, #"0" wc,wz
        if_c        jmp     #:l1
                    cmp     ch, #"9"+1 wc,wz
        if_nc       jmp     #:l1
:s1                 mov     t1, args                ' multiply x 10
                    shl     t1, #1
                    mov     t2, t1
                    shl     t2, #2
                    add     t2, t1
                    sub     ch, #"0"                ' adds digit
                    add     t2, ch
:d1                 mov     args, t2
                    jmp     #:l2
:l1                 cmp     ch, #";" wz
        if_nz       jmp     #:l3
                    add     argc, #1
                    add     :d1, incdst
                    add     :d2, incdst
                    add     :s1, #1
:d2                 mov     args, #0
                    jmp     #:l2

:l3                 cmp     ch, #"A" wz
        if_z        jmp     #_up
                    cmp     ch, #"B" wz
        if_z        jmp     #_down
                    cmp     ch, #"C" wz
        if_z        jmp     #_right
                    cmp     ch, #"D" wz
        if_z        jmp     #_left
                    cmp     ch, #"H" wz
        if_z        jmp     #_cup
                    cmp     ch, #"f" wz
        if_z        jmp     #_cup
                    cmp     ch, #"m" wz
        if_z        mov     overlay_par, attr_overlay_par
        if_z        jmp     #overlay_load

                    mov     overlay_par, vt_overlay_par
                    jmp     #overlay_load

_up                 cmp     args, #0 wz
        if_z        add     args, #1
                    sub     y, args wc
        if_c        mov     y, #0
                    jmp     #_done

_down               cmp     args, #0 wz
        if_z        add     args, #1
                    add     y, args
                    cmp     y, #rows wc
        if_nc       mov     y, #rows-1
                    jmp     #_done

_right              cmp     args, #0 wz
        if_z        add     args, #1
                    add     x, args
                    cmp     x, #columns wc
        if_nc       mov     x, #columns-1
                    jmp     #_done

_left               cmp     args, #0 wz
        if_z        add     args, #1
                    sub     x, args wc
        if_c        mov     x, #0
                    jmp     #_done

_cup                mov     y, args
                    cmp     y, #rows wc
        if_nc       mov     y, #rows
                    cmpsub  y, #1
                    mov     x, args+1
                    cmp     x, #columns wc
        if_nc       mov     x, #columns
                    cmpsub  x, #1
                    jmp     #_done

                    long    $0[($ - overlay_start) // 2]
_esc_end            fit     $1F0

                    org     overlay_start

_attr               mov     a, args
                    cmp     a, #0 wz                ' reset attr
        if_z        jmp     #:reset
                    cmp     a, #1 wz                ' bright
        if_z        jmp     #:bright
                    cmp     a, #5 wz                ' blink
        if_z        jmp     #:blink
                    cmp     a, #7 wz                ' reverse
        if_z        jmp     #:reverse
                    cmp     a, #30 wc               ' foreground
        if_c        jmp     #:l2
                    cmp     a, #38 wc,wz
        if_c        jmp     #:fg
        if_z        jmp     #:ext_fg
:l2                 cmp     a, #39 wz               ' reset foreground
        if_z        jmp     #:res_fg
                    cmp     a, #40 wc               ' background
        if_c        jmp     #:l3
                    cmp     a, #48 wc,wz
        if_c        jmp     #:bg
        if_z        jmp     #:ext_bg
:l3                 cmp     a, #49 wz               ' reset background
        if_z        jmp     #:res_bg

:l1                 add     _attr, #1
                    sub     argc, #1 wc
        if_nc       jmp     #_attr
                    jmp     #_done

:reset              mov     txt_attr, #$70
                    jmp     #:l1
:bright             or      txt_attr, #$80
                    jmp     #:l1
:blink              or      txt_attr, #$01
                    jmp     #:l1
:reverse            mov     t1, txt_attr
                    and     t1, #$0E
                    shl     t1, #3
                    and     txt_attr, #$70
                    shr     txt_attr, #3
                    or      txt_attr, t1
                    jmp     #:l1
:fg                 sub     a, #30
                    shl     a, #4
                    and     txt_attr, #$8F
                    or      txt_attr, a
                    jmp     #:l1
:ext_fg             add     _attr, #1
                    movs    :xs1, _attr
                    add     _attr, #1
                    movs    :xs2, _attr
                    sub     argc, #2
:xs1                mov     a, 0-0
                    cmp     a, #2 wz                ' 38;2;r;g;b not supported, skip
        if_z        jmp     #:xs3
                    cmp     a, #5 wz                ' 38;5;n supported for n <= 15
        if_nz       jmp     #:l1
:xs2                mov     a, 0-0
                    cmp     a, #16 wc
        if_nc       jmp     #:l1
                    shl     a, #4
                    and     txt_attr, #$0F
                    or      txt_attr, a
                    jmp     #:l1
:xs3                add     _attr, #2
                    sub     argc, #2
                    jmp     #:l1
:res_fg             and     txt_attr, #$0F
                    or      txt_attr, #$70
                    jmp     #:l1
:bg                 sub     a, #40
                    shl     a, #1
                    and     txt_attr, #$F1
                    or      txt_attr, a
                    jmp     #:l1
:ext_bg             add     _attr, #1
                    movs    :xs4, _attr
                    add     _attr, #1
                    movs    :xs5, _attr
                    sub     argc, #2
:xs4                mov     a, 0-0
                    cmp     a, #2 wz                ' 48;2;r;g;b not supported, skip
        if_z        jmp     #:xs6
                    cmp     a, #5 wz                ' 48;5;n supported for n <= 7
        if_nz       jmp     #:l1
:xs5                mov     a, 0-0
                    cmp     a, #8 wc
        if_nc       jmp     #:l1
                    shl     a, #1
                    and     txt_attr, #$F1
                    or      txt_attr, a
                    jmp     #:l1
:xs6                add     _attr, #2
                    sub     argc, #2
                    jmp     #:l1
                    jmp     #:l1
:res_bg             and     txt_attr, #$F1
                    jmp     #:l1

                    long    $0[($ - overlay_start) // 2]
_attr_end           fit     $1F0

                    org     overlay_start

_vt                 cmp     ch_mod, #"?" wz
        if_z        jmp     #_pvt

                    cmp     ch, #"J" wz
        if_z        jmp     #_ed
                    cmp     ch, #"K" wz
        if_z        jmp     #_el
                    cmp     ch, #"L" wz
        if_z        jmp     #_ins_line
                    cmp     ch, #"M" wz
        if_z        jmp     #_del_line
                    cmp     ch, #"n" wz
        if_z        jmp     #_cursor_report
                    cmp     ch, #"q" wz
        if_z        jmp     #_cursor_style
                    cmp     ch, #"s" wz
        if_z        jmp     #_save
                    cmp     ch, #"u" wz
        if_z        jmp     #_restore
                    jmp     #_done

_pvt                cmp     ch, #"h" wz             ' private escape sequences
        if_z        jmp     #_toggles
                    cmp     ch, #"l" wz
        if_z        jmp     #_toggles
                    jmp     #_done

_save               mov     txt_cursor_s, y
                    shl     txt_cursor_s, #16
                    or      txt_cursor_s, x
                    jmp     #_done

_restore            mov     x, txt_cursor_s
                    and     x, #$1FF
                    mov     y, txt_cursor_s
                    shr     y, #16
                    jmp     #_done

_ed                 cmp     args, #2 wz             ' clear entire screen
        if_z        jmp     #_cls

                    mov     t1, y                   ' t2 := y * 80
                    shl     t1, #4
                    mov     t2, t1
                    shl     t2, #2
                    add     t2, t1
                    add     t2, x                   ' t2 := t2 + x
                    mov     t1, txt_scrn
                    sub     t1, t2
                    sub     t1, t2                  ' t1 := pointer to cursor location

                    mov     a, #$20
                    shl     a, #8
                    or      a, txt_attr

                    cmp     args, #1 wz
        if_z        jmp     #:ed1
                    cmp     args, #0 wz
        if_z        jmp     #:ed0
                    jmp     #_done
:ed0                mov     t3, txt_bcnt
                    sub     t3, t2
                    sub     t1, #2                  ' clear screen from cursor down
                    wrword  a, t1
                    djnz    t3, #$-2
                    jmp     #_done
:ed1                mov     t3, t2                  ' clear screen from cursor up
                    add     t3, #1
                    sub     t1, #2
                    wrword  a, t1
                    add     t1, #2
                    djnz    t3, #$-2
                    jmp     #_done

_ins_line           mov     t1, y
                    shl     t1, #4
                    mov     t2, t1
                    shl     t2, #2
                    add     t2, t1

                    mov     t3, txt_bcnt
                    sub     t3, #columns
                    sub     t3, t2

                    mov     t1, txt_scrn
                    sub     t1, txt_bcnt
                    sub     t1, txt_bcnt

                    cmp     y, #rows-1 wz
        if_z        jmp     #:l3

                    mov     t2, t1
                    add     t2, #columns << 1

:l1                 rdword  a, t2
                    add     t2, #2
                    wrword  a, t1
                    add     t1, #2
                    djnz    t3, #:l1

:l3                 mov     t2, #$20
                    shl     t2, #8
                    or      t2, txt_attr
                    mov     a, t2
                    shl     a, #16
                    or      a, t2
                    mov     t3, #columns >> 1
:l2                 wrlong  a, t1
                    add     t1, #4
                    djnz    t3, #:l2

                    jmp     #_done

_del_line           mov     t1, y
                    shl     t1, #4
                    mov     t2, t1
                    shl     t2, #2
                    add     t2, t1

                    mov     t1, txt_scrn
                    sub     t1, t2
                    sub     t1, t2
                    sub     t1, #2

                    cmp     y, #rows-1 wz
        if_z        jmp     #:l3

                    mov     t3, txt_bcnt
                    sub     t3, t2
                    sub     t3, #columns

                    mov     t2, t1
                    sub     t2, #columns << 1

:l1                 rdword  a, t2
                    sub     t2, #2
                    wrword  a, t1
                    sub     t1, #2
                    djnz    t3, #:l1

:l3                 mov     t2, #$20
                    shl     t2, #8
                    or      t2, txt_attr
                    mov     a, t2
                    shl     a, #16
                    or      a, t2
                    mov     t3, #columns >> 1
:l2                 wrlong  a, t1
                    sub     t1, #4
                    djnz    t3, #:l2

                    jmp     #_done

_el                 mov     t1, y                   ' t1 := y * 80
                    shl     t1, #4
                    mov     t2, t1
                    shl     t2, #2
                    add     t2, t1
                    mov     t1, txt_scrn
                    sub     t1, t2
                    sub     t1, t2                  ' t1 := pointer to begin of line at cursor

                    mov     a, #$20
                    shl     a, #8
                    or      a, txt_attr

                    cmp     args, #0 wz
        if_z        jmp     #:el0
                    cmp     args, #1 wz
        if_z        jmp     #:el1
                    cmp     args, #2 wz
        if_z        jmp     #:el2
                    jmp     #_done
:el0                sub     t1, x                   ' clear line from cursor right
                    sub     t1, x
                    mov     t3, #columns
                    sub     t3, x
                    sub     t1, #2
                    wrword  a, t1
                    djnz    t3, #$-2
                    jmp     #_done
:el1                mov     t3, x                   ' clear line from cursor left
                    add     t3, #1
                    sub     t1, #2
                    wrword  a, t1
                    djnz    t3, #$-2
                    jmp     #_done
:el2                mov     t3, #columns            ' clear entire line
                    sub     t1, #2
                    wrword  a, t1
                    djnz    t3, #$-2
                    jmp     #_done

_cursor_style       rdbyte  t1, txt_cursor
                    and     t1, #CURSOR_ON

                    cmp     args, #0 wz
        if_nz       cmp     args, #1 wz
        if_z        or      t1, #CURSOR_FLASH

                    cmp     args, #3 wz
        if_z        or      t1, #CURSOR_FLASH
        if_nz       cmp     args, #4 wz
        if_z        or      t1, #CURSOR_ULINE

                    wrbyte  t1, txt_cursor
                    jmp     #_done

_toggles            cmp     args, #1 wz
        if_z        jmp     #_key_mode
                    cmp     args, #12 wz
        if_z        jmp     #_blink
                    cmp     args, #25 wz
        if_z        jmp     #_display
                    jmp     #_done

_key_mode           cmp     ch, #"l" wz             ' cursor key mode
        if_z        wrlong  kb_str_table_1, kb_str_table_ptr
        if_nz       wrlong  kb_str_table_2, kb_str_table_ptr
                    jmp     #_done

kb_str_table_ptr    long    0
kb_str_table_1      long    0
kb_str_table_2      long    0

_blink              rdbyte  t1, txt_cursor          ' enable / disable blinking
                    cmp     ch, #"l" wz
        if_z        andn    t1, #CURSOR_FLASH
        if_nz       or      t1, #CURSOR_FLASH
                    wrbyte  t1, txt_cursor
                    jmp     #_done

_display            rdbyte  t1, txt_cursor          ' show / hide cursor
                    cmp     ch, #"l" wz
        if_z        andn    t1, #CURSOR_ON
        if_nz       or      t1, #CURSOR_ON
                    wrbyte  t1, txt_cursor
                    jmp     #_done

_cursor_report      cmp     args, #6 wz
        if_nz       jmp     #_done
                    mov     ch, #$1B
                    call    #charOut
                    mov     ch, #"["
                    call    #charOut
                    mov     a, y
                    add     a, #1
                    call    #decOut
                    mov     ch, #";"
                    call    #charOut
                    mov     a, x
                    add     a, #1
                    call    #decOut
                    mov     ch, #"R"
                    call    #charOut
                    jmp     #_done

charOut             rdlong  t2, tx_head
                    mov     t1, tx_buffer
                    add     t1, t2
                    wrbyte  ch, t1
                    add     t2, #1
                    and     t2, #ser#BUFFER_MASK
                    wrlong  t2, tx_head
charOut_ret         ret

decOut              mov     ch, #"0"
                    cmpsub  a, #10 wc
        if_c        add     ch, #1
        if_c        jmp     #$-2
                    cmp     ch, #"0" wz
        if_nz       call    #charOut
                    mov     ch, #"0"
                    add     ch, a
                    call    #charOut
decOut_ret          ret

                    long    $0[($ - overlay_start) // 2]
_vt_end             fit     $1F0

PUB usb_hid | retval, ifd, epd

    debug.str(string(debug#CS, "USB Started", debug#NL, debug#LF))

    repeat
        if \hc.Enumerate < 0
            waitcnt(CNT + CLKFREQ)
            next

        debug.str(string("Found device "))
        debug.hex(hc.VendorID, 4)
        debug.char(":")
        debug.hex(hc.ProductID, 4)
        debug.str(string(debug#NL, debug#LF))

        if showError(\hc.Configure, string("Error configuring device"))
            repeat
                waitcnt(CNT + CLKFREQ)
            while hc.GetPortConnection <> hc#PORTC_NO_DEVICE
            debug.str(string("Device disconnected", debug#NL, debug#LF))
            next

        if not (ifd := hc.FindInterface(3))
            debug.str(string("Device has no HID interfaces", debug#NL, debug#LF))
            repeat
                waitcnt(CNT + CLKFREQ)
            while hc.GetPortConnection <> hc#PORTC_NO_DEVICE
            debug.str(string("Device disconnected", debug#NL, debug#LF))
            next
        else
            debug.str(string("Device has HID interfaces", debug#NL, debug#LF))

        ' First endpoint on the first HID interface
        epd := hc.NextEndpoint(ifd)

        ' Blink LEDs
        usb_led := LED_NUM_LOCK|LED_CAPS_LOCK|LED_SCROLL_LOCK
        hc.ControlWrite(REQ_SET_REPORT, REPORT_TYPE_OUTPUT, 0, @usb_led, 1)
        waitcnt(CNT + CLKFREQ / 2)
        usb_led := 0
        hc.ControlWrite(REQ_SET_REPORT, REPORT_TYPE_OUTPUT, 0, @usb_led, 1)

        kb_last := 0
        kb_timer := 0

        repeat while hc.GetPortConnection <> hc#PORTC_NO_DEVICE
            retval := \hc.InterruptRead(epd, @usb_buf, 64)

            if retval == hc#E_TIMEOUT
                ' No data available. Try again later.

            elseif not showError(retval, string("Read Error"))
                ' Successful transfer
                'debug.char("[")
                'debug.dec(retval)
                'debug.str(string(" bytes] "))
                'hexDump(@usb_buf, retval)
                decode(@usb_buf)
                'debug.str(string(debug#NL, debug#LF))

            if kb_last <> 0 and kb_timer <> 0
                if (kb_timer - CNT) =< 0
                    keyPressed(kb_last, kb_mod)
                    kb_timer := CNT + (CLKFREQ / 1000 * REPEAT_RATE)

        debug.str(string("Device disconnected", debug#NL, debug#LF))
        waitcnt(CNT + CLKFREQ)

PRI decode(buffer) | i, k, mod

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

    repeat i from 2 to 7
        k := BYTE[buffer][i]
        if k <> 0 and lookdown(k : usb_report[2], usb_report[3], usb_report[4], usb_report[5], usb_report[6], usb_report[7]) == 0
            keyPressed(k, mod)

            if k <> kb_last
                kb_last := k
                kb_mod := mod
                kb_timer := CNT + (CLKFREQ / 1000 * REPEAT_DELAY)

        usb_report[i] := k

    if kb_last <> 0 and lookdown(kb_last : BYTE[buffer][2], BYTE[buffer][3], BYTE[buffer][4], BYTE[buffer][5], BYTE[buffer][6], BYTE[buffer][7]) == 0
        kb_last := 0

PRI keyPressed(k, mod) | c, ptr

    if (usb_led & LED_NUM_LOCK) and k => $59 and k =< $63
        c := keymap.map(k, 1)
    else
        c := keymap.map(k, mod)
    case c
        "A".."Z":
            if (usb_report[0] & %00010001) ' CTRL
                ser.char(c - "A" + 1)
            else
                ser.char(c)
        "a".."z":
            if (usb_report[0] & %00010001) ' CTRL
                ser.char(c - "a" + 1)
            elseif (usb_led & LED_CAPS_LOCK)
                ser.char(c ^ $20)
            else
                ser.char(c)
        0..$FF:
            ser.char(c)

        kb#KeyNumLock:
            usb_led ^= LED_NUM_LOCK
            hc.ControlWrite(REQ_SET_REPORT, REPORT_TYPE_OUTPUT, 0, @usb_led, 1)
        kb#KeyCapsLock:
            usb_led ^= LED_CAPS_LOCK
            hc.ControlWrite(REQ_SET_REPORT, REPORT_TYPE_OUTPUT, 0, @usb_led, 1)
        kb#KeyScrollLock:
            usb_led ^= LED_SCROLL_LOCK
            hc.ControlWrite(REQ_SET_REPORT, REPORT_TYPE_OUTPUT, 0, @usb_led, 1)

        kb#KeySpace..kb#KeyMaxCode:
            ptr := @@word[kb_str_table][c - kb#KeySpace]
            repeat strsize(ptr)
                ser.char(byte[ptr])
                ptr++


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

CON

    #1, CTRL_A, CTRL_B, CTRL_C, CTRL_D, CTRL_E, CTRL_F, CTRL_G, CTRL_H, CTRL_I, CTRL_J, CTRL_K, CTRL_L, CTRL_M, CTRL_N, CTRL_O, CTRL_P, CTRL_Q, CTRL_R, CTRL_S, CTRL_T, CTRL_U, CTRL_V, CTRL_W, CTRL_X, CTRL_Y, CTRL_Z, ESC

DAT

' Default (cursor) mode keys table

strTable            word    @strKeySpace
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
                    word    @strKeyShiftLeft
                    word    @strKeyShiftRight

' Application mode keys table

strTableApp         word    @strKeySpace
                    word    @strKeyEscape
                    word    @strKeyBackspace
                    word    @strKeyTabulator
                    word    @strKeyReturn
                    word    @strAppKeyInsert
                    word    @strAppKeyHome
                    word    @strAppKeyPageUp
                    word    @strAppKeyDelete
                    word    @strAppKeyEnd
                    word    @strAppKeyPageDown
                    word    @strAppKeyUp
                    word    @strAppKeyDown
                    word    @strAppKeyLeft
                    word    @strAppKeyRight
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
                    word    @strKeyShiftLeft
                    word    @strKeyShiftRight

' Common default (cursor) and application mode keys

strKeySpace         byte    " ", 0
strKeyEscape        byte    $1B, 0
strKeyBackspace     byte    $08, 0
strKeyTabulator     byte    $09, 0
strKeyReturn        byte    $0D, 0

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
strKeyF11           byte    0
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

' Default (cursor) mode keys

strKeyInsert        byte    0
strKeyHome          byte    $1B, "[H", 0
strKeyPageUp        byte    0
strKeyDelete        byte    $7F, 0
strKeyEnd           byte    $1B, "[K", 0
strKeyPageDown      byte    0
strKeyUp            byte    $1B, "OA", 0
strKeyDown          byte    $1B, "OB", 0
strKeyLeft          byte    $1B, "OD", 0
strKeyRight         byte    $1B, "OC", 0
strKeyShiftLeft     byte    0
strKeyShiftRight    byte    0

' Application mode keys

strAppKeyInsert     byte    CTRL_V, 0
strAppKeyHome       byte    CTRL_Q, "S", 0
strAppKeyPageUp     byte    CTRL_R, 0
strAppKeyDelete     byte    CTRL_G, 0
strAppKeyEnd        byte    CTRL_Q, "D", 0
strAppKeyPageDown   byte    CTRL_C, 0
strAppKeyUp         byte    CTRL_E, 0
strAppKeyDown       byte    CTRL_X, 0
strAppKeyLeft       byte    CTRL_S, 0
strAppKeyRight      byte    CTRL_D, 0
strAppKeyShiftLeft  byte    CTRL_A, 0
strAppKeyShiftRight byte    CTRL_F, 0

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

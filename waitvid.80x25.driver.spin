''
'' VGA display 80x25 (dual cog) - video driver and pixel generator
''
''        Author: Marko Lukat
'' Last modified: 2015/06/15
''       Version: 0.15
''
'' long[par][0]: vgrp:mode:vpin:[!Z]:addr = 2:1:8:5:16 -> zero (accepted) screen buffer   (4n)
'' long[par][1]:                [!Z]:addr =      16:16 -> zero (accepted) font descriptor (2n)
'' long[par][2]:                addr:addr =      16:16 -> zero (accepted) cursor location (4n)
'' long[par][3]: frame indicator/sync lock
''
'' - character entries are words, i.e. ASCII << 8 | attribute
'' - top left corner is at highest screen memory address
''
'' - cursor location:   $00000000: both cursors off
''                      $BBBBAAAA: AAAA == BBBB, one cursor
''                      $DDDDCCCC: CCCC <> DDDD, two cursors
''
'' - cursor format:     %00000000_yyyyyyyy_xxxxxxxx_00000_mmm (see below for mode flags)
''
'' acknowledgements
'' - loader code based on work done by Phil Pilgrim (PhiPi)
''
'' 20140912: initial version (720x400@70Hz timing, %10 sync locked)
'' 20140914: dual cog timing sorted (colours are under our control)
'' 20140915: pixel loader, use internal 128 entry palette (fixed)
'' 20140916: enabled blink mode (0/1)
'' 20140918: blink mode is now an init time parameter
'' 20140919: cursor, WIP
'' 20140920: cursor implementation complete
'' 20140926: added cursor mask constant
'' 20150615: full character range (9th column is always background)
'' 20171027: modified colors table (Marco Maccaferri)
'' 20171104: added conditional compile and timings for 640x400@70Hz (Marco Maccaferri)
'' 20180507: modified cursor mask to act on pixels only (Marco Maccaferri)
''
CON
  CURSOR_ON    = %100
  CURSOR_OFF   = %000
  CURSOR_ULINE = %010
  CURSOR_BLOCK = %000
  CURSOR_FLASH = %001
  CURSOR_SOLID = %000

  CURSOR_MASK  = %111

PUB null
'' This is not a top level object.

PUB init(ID, mailbox)

  long[mailbox][3] := 0

  cognew(@driver, mailbox)
  cognew(@driver, mailbox | $8000)

  repeat
  until long[mailbox][3] == $0000FFFF       ' OK (secondary/primary)

  long[mailbox][3] := 0                         ' release sync lock

DAT             org     0                       ' video driver

driver          jmpret  $, #setup               '  -4   once

' %00_11_11_10

' Palette entries holds two pairs of FG/BG colours (high word: blink colours, low word: normal colours).

                long               $82020282, $22020222, $A20202A2, $0A02020A, $8A02028A, $2A02022A, $AA0202AA
                long    $02828202, $82828282, $22828222, $A28282A2, $0A82820A, $8A82828A, $2A82822A, $AA8282AA
                long    $02222202, $82222282, $22222222, $A22222A2, $0A22220A, $8A22228A, $2A22222A, $AA2222AA
                long    $02A2A202, $82A2A282, $22A2A222, $A2A2A2A2, $0AA2A20A, $8AA2A28A, $2AA2A22A, $AAA2A2AA
                long    $020A0A02, $820A0A82, $220A0A22, $A20A0AA2, $0A0A0A0A, $8A0A0A8A, $2A0A0A2A, $AA0A0AAA
                long    $028A8A02, $828A8A82, $228A8A22, $A28A8AA2, $0A8A8A0A, $8A8A8A8A, $2A8A8A2A, $AA8A8AAA
                long    $022A2A02, $822A2A82, $222A2A22, $A22A2AA2, $0A2A2A0A, $8A2A2A8A, $2A2A2A2A, $AA2A2AAA
                long    $02AAAA02, $82AAAA82, $22AAAA22, $A2AAAAA2, $0AAAAA0A, $8AAAAA8A, $2AAAAA2A, $AAAAAAAA
                long    $02565602, $82565682, $22565622, $A25656A2, $0A56560A, $8A56568A, $2A56562A, $AA5656AA
                long    $02C2C202, $82C2C282, $22C2C222, $A2C2C2A2, $0AC2C20A, $8AC2C28A, $2AC2C22A, $AAC2C2AA
                long    $02323202, $82323282, $22323222, $A23232A2, $0A32320A, $8A32328A, $2A32322A, $AA3232AA
                long    $02F6F602, $82F6F682, $22F6F622, $A2F6F6A2, $0AF6F60A, $8AF6F68A, $2AF6F62A, $AAF6F6AA
                long    $020E0E02, $820E0E82, $220E0E22, $A20E0EA2, $0A0E0E0A, $8A0E0E8A, $2A0E0E2A, $AA0E0EAA
                long    $02CECE02, $82CECE82, $22CECE22, $A2CECEA2, $0ACECE0A, $8ACECE8A, $2ACECE2A, $AACECEAA
                long    $023E3E02, $823E3E82, $223E3E22, $A23E3EA2, $0A3E3E0A, $8A3E3E8A, $2A3E3E2A, $AA3E3EAA
                long    $02FEFE02, $82FEFE82, $22FEFE22, $A2FEFEA2, $0AFEFE0A, $8AFEFE8A, $2AFEFE2A, $AAFEFEAA

' horizontal timing 720(720)  1(18) 6(108) 3(54)
'   vertical timing 400(400) 13(13) 2(2)  34(34)

'                               +---------------- front porch
'                               | +-------------- sync
'                               | |    +--------- back porch
'                               | |    |
vsync
#ifdef VGA_MODE_720
                mov     ecnt, #13+2+(34-2)

                cmp     ecnt, #34 wz
        if_ne   cmp     ecnt, #32 wz
#else
                mov     ecnt, #12+2+(35-2)

                cmp     ecnt, #35 wz
        if_ne   cmp     ecnt, #33 wz
#endif
        if_e    xor     sync, #$0101            ' in/active

                call    #blank
                djnz    ecnt, #vsync+1

' While still in sync, figure out the blink mode (used to be based on cnt) and cursor.
' hsync offers 31 hub windows.

                add     fcnt, #1                ' next frame
                cmpsub  fcnt, #36 wz            ' N frames per phase (on/off)
        if_z    rev     rcnt, #{32}-0           ' toggle colours

                cmp     locn, #0 wz             ' check cursor availability
                mov     crs0, #0                ' default is disabled
        if_ne   rdlong  crs0, locn              ' override
        if_ne   rol     locn, #16
                mov     crs1, #0                ' default is disabled
        if_ne   rdlong  crs1, locn              ' override

                mov     vier, crs0              ' |
                call    #prep                   ' process cursor 0
                mov     crs0, vier              ' |

                mov     vier, crs1              ' |
                call    #prep                   ' process cursor 1
                mov     crs1, vier              ' |

                rdlong  temp, scrn_ wz          ' get screen address
        if_nz   wrlong  zero, scrn_             ' acknowledge screen buffer setup
        if_nz   mov     scrn, temp
        if_nz   add     scrn, $+1               ' scrn now points to last byte
                long    160*25 -1

        if_nc   call    #blank                  ' |
        if_nc   call    #blank                  ' back porch remainder (primary only)

' Vertical sync chain done, do visible area.

                mov     zwei, scrn              ' screen base address
                mov     rows, #res_y/16         ' row count

:scan           mov     scnt, #16/2/2           ' 16 double scanlines (split between primary and secondary)
                mov     eins, font              ' font base
        if_nc   add     eins, dst1              ' interleaved

:line           mov     vscl, many              ' two lines we don't use
                waitvid zero, #0                ' 317 hub windows

                call    #load                   ' load pixels and colours for the next two lines

                call    #chars                  ' |
                call    #chars                  ' display scanlines

                add     eins, dst2{512+512}     ' skip 4 scanlines
                djnz    scnt, #:line            ' for all character scanlines
                sub     zwei, #80*2             ' next row
                djnz    rows, #:scan            ' for all rows


        if_c    call    #blank                  ' secondary finishes early so
        if_c    call    #blank                  ' let him do some blank lines

        if_nc   wrlong  cnt, fcnt_              ' announce vertical blank (primary)

                jmp     #vsync                  ' next frame


blank           mov     vscl, line              ' 256/640{720}
                waitvid sync, #%0000            ' latch blank line
                call    #hsync
blank_ret       ret


chars           movd    :one, #pix+0            ' |
                movd    :two, #col+0            ' restore initial settings
                movs    :two, #pix+0            ' |

                mov     vscl, hvis              ' 1/8{9}, speed up (one pixel per frame clock)
                mov     ecnt, #80               ' character count

:one            ror     1-1, #8                 ' $0000AABB -> $BB0000AA -> $000000BB
                add     $-1, dst1               ' advance
                add     $+1, d1s1               ' advance (pipeline)
:two            waitvid 0-0, 1-1                ' emit pixels (9th column is background)
                djnz    ecnt, #$-4

                xor     :one, swap              ' ror #8 vs shr #24

' Horizontal sync embedded here due to timing constraints, only 18 clocks are allowed between waitvids.

hsync           mov     vscl, wrap              ' |
                waitvid sync, #%0001111110      ' horizontal sync pulse (1/6/3 reverse)
                mov     cnt, cnt                ' record sync point
hsync_ret
chars_ret       ret


load            muxnc   flag, $                 ' preserve carry flag

                movd    :ld_0, #pix+0           ' |
                movd    :ld_1, #pix+1           ' |
                movd    :ld_2, #pix+2           ' re/store initial settings
                movd    :ld_3, #pix+3           ' |

                movd    :wr_0, #col+0           ' |
                movd    :wr_1, #col+1           ' |
                movd    :wr_2, #col+2           ' same for colours
                movd    :wr_3, #col+3           ' |

                mov     addr, zwei              ' current screen base
                movi    addr, #80{units} -4     ' add magic marker

' Fetch pixel data and colour for four characters. Only character 4n is documented.

:loop           rdword  frqb, addr              '  +0 = {p.0.0} read ASCII + colour
                ror     frqb, #8                '  +8   {p.0.1} select ASCII for indexed read
                mov     phsb, eins              '  -4   {p.0.2} current font address
:ld_0           rdword  0-0, phsb               '  +0 = {p.0.3} two scanlines worth of character data
                add     $-1, dst4               '  +8   {p.0.4} advance dst

                test    frqb, bt24 wz           '  -4                   {c.0.0} check blink mode
                shr     frqb, #25               '  +0 =                 {c.0.1} palette index
                movs    :rd_0, frqb             '  +4                   {c.0.2} prepare palette-to-temp

                sub     addr, #3                '  +8   {p.0.5} advance src
:rd_0           mov     col0, 0-0               '  -4                   {c.0.3} read palette entry


                rdword  frqb, addr              '  +0 = {p.1.0}
                ror     frqb, #8                '  +8   {p.1.1}
                mov     phsb, eins              '  -4   {p.1.2}
:ld_1           rdword  1-1, phsb               '  +0 = {p.1.3}
                add     $-1, dst4               '  +8   {p.1.4}
                sub     addr, #1                '  -4   {p.1.5}

        if_nz   rol     col0, rcnt              '  +0 =                 {c.0.4} optionally select alternate colour

                test    frqb, bt24 wz           '  +4                   {c.1.0}
                shr     frqb, #25               '  +8                   {c.1.1}
                movs    :rd_1, frqb             '  -4                   {c.1.2}


                rdword  frqb, addr              '  +0 = {p.2.0}

:wr_0           mov     0-0, col0               '  +4                   {c.0.5} transfer temp to colour array
                add     $-1, dst4               '  +8                   {c.0.6} advance destination
:rd_1           mov     col1, 1-1               '  -4                   {c.1.3}
        if_nz   rol     col1, rcnt              '  +0 =                 {c.1.4}

                ror     frqb, #8                '  +8   {p.2.1}
                mov     phsb, eins              '  -4   {p.2.2}
:ld_2           rdword  2-2, phsb               '  +0 = {p.2.3}
                add     $-1, dst4               '  +8   {p.2.4}

                test    frqb, bt24 wz           '  -4                   {c.2.0}
                shr     frqb, #25               '  +0 =                 {c.2.1}
                movs    :rd_2, frqb             '  +4                   {c.2.2}

                sub     addr, i4s3 wc           '  +8   {p.2.5}
:rd_2           mov     col2, 2-2               '  -4                   {c.2.3}


                rdword  frqb, addr              '  +0 = {p.3.0}
                ror     frqb, #8                '  +8   {p.3.1}
                mov     phsb, eins              '  -4   {p.3.2}
:ld_3           rdword  3-3, phsb               '  +0 = {p.3.3}
                add     $-1, dst4               '  +8   {p.3.4}

:wr_1           mov     1-1, col1               '  -4                   {c.1.5}
                add     $-1, dst4               '  +0 =                 {c.1.6}
        if_nz   rol     col2, rcnt              '  +4                   {c.2.4}

                test    frqb, bt24 wz           '  +8                   {c.3.0}
                shr     frqb, #25               '  -4                   {c.3.1}
                movs    :rd_3, frqb             '  +0 =                 {c.3.2}

:wr_2           mov     2-2, col2               '  +4                   {c.2.5}
                add     $-1, dst4               '  +8                   {c.2.6}

:rd_3           mov     col3, 3-3               '  -4                   {c.3.3}
        if_nz   rol     col3, rcnt              '  +0 =                 {c.3.4}
:wr_3           mov     3-3, col3               '  +4                   {c.3.5}
                add     $-1, dst4               '  +8                   {c.3.6}

        if_nc   djnz    addr, #:loop            '  -4   {p.3.5} for all characters

                mov     vier, crs0
                call    #cursor

                cmp     crs0, crs1 wz
        if_ne   mov     vier, crs1
        if_ne   call    #cursor

load_ret        jmpret  flag, #0-0 nr,wc        ' restore carry flag


cursor          test    vier, #%100 wz          ' cursor enabled?

                mov     temp, vier              ' local copy
                sar     temp, #1+16             ' extract y - 25
        if_z    add     temp, rows wz           ' rows = {25..1}
        if_nz   jmp     cursor_ret              ' wrong row/disabled

                test    vier, #%010 wz,wc       ' underscore(1)/block(0)
        if_nz   cmp     scnt, #1 wz
        if_nz   jmp     cursor_ret              ' wrong scanline pair

                ror     vier, #8 wc             ' carry: blink on/off
                movd    :set, vier
        if_c    cmp     fcnt, #18 wc
:set    if_nc   xor     0-0, cmsk

cursor_ret      ret


prep            mov     temp, vier              ' working copy
                shr     temp, #16               ' |
                and     temp, #255              ' extract y
                sub     temp, #25               '   y - 25
                shl     temp, #1+16             ' 2(y - 25)

                and     vier, xmsk              ' get rid of y
                max     vier, xlim              ' limit x to park position (auto off)
                xor     vier, #%100             ' invert on/off
                or      vier, temp              ' reinsert y

                ror     vier, #8                ' align x for add
                add     vier, #pix
                rol     vier, #8                ' restore cursor descriptor

prep_ret        ret

' initialised data and/or presets

xmsk            long    $0000FF07               ' covers mode/x
xlim            long    80 << 8                 ' park position

rcnt            long    8                       ' palette bit rotation count (16/8/0)
fcnt            long    0                       ' blink frame count
bt24            long    |< 24                   ' blink indicator

flag            long    0                       ' loader flag storage
swap            long    %000010 << 26 | 16      ' ror #8 vs shr #24
sync            long    hv_idle ^ $0200

#ifdef VGA_MODE_720
wrap            long     18 << 12 | 180         '  18/180
hvis            long      1 << 12 | 9           '   1/9
line            long    180 << 12 | 720         ' 180/720
many            long      0 << 12 | 1800        ' 256/1800
#else
wrap            long     16 << 12 | 160         '  16/160
hvis            long      1 << 12 | 8           '   1/8
line            long      0 << 12 | 640         ' 256/640
many            long      0 << 12 | 1600        ' 256/1600
#endif

scrn_           long    $00000000 -12           ' |
font_           long    $00000004 -12           ' |
locn_           long    $00000008 -12           ' |
fcnt_           long    $0000000C -12           ' mailbox addresses (local copy)        (##)

dst1            long    1 << 9                  ' dst     +/-= 1
dst2            long    2 << 9                  ' dst     +/-= 2
dst4            long    4 << 9                  ' dst     +/-= 4
d1s1            long    1 << 9  | 1             ' dst/src +/-= 1
i4s3            long    4 << 23 | 3

cmsk            long    %%3333_3333             ' xor mask for cursor

' Stuff below is re-purposed for temporary storage.

setup           add     trap, par wc            ' carry set -> secondary
                and     trap, hram              ' confine to hub RAM

                add     scrn_, trap             ' @long[par][0]
                add     font_, trap             ' @long[par][1]
                add     locn_, trap             ' @long[par][2]
                add     fcnt_, trap             ' @long[par][3]

                addx    trap, #%00              ' add secondary offset
                wrbyte  hram, trap              ' up and running

                rdlong  temp, trap wz           ' |                                     (%%)
        if_nz   jmp     #$-1                    ' synchronized start

'   primary: cnt + 0
' secondary: cnt + 2

                rdlong  scrn, scrn_             ' get screen address  (4n)              (%%)
                wrlong  zero, scrn_             ' acknowledge screen buffer setup

                rdlong  font, font_             ' get font definition (2n)              (%%)
                wrlong  zero, font_             ' acknowledge font definition setup

                rdlong  locn, locn_ wz          ' get cursor location                   (%%)
        if_nz   wrlong  zero, locn_             ' acknowledge cursor location

' Perform pending setup.

                add     scrn, $+1               ' scrn now points to last byte
                long    160*25 -1

' Upset video h/w and relatives.

                rdlong  temp, #0                ' clkfreq
                shr     temp, #10               ' ~1ms
        if_nc   waitpne $, #0                   ' adjust primary

'   primary: cnt + 0 + 6
' secondary: cnt + 2 + 4

                add     temp, cnt

                movi    ctrb, #%0_11111_000     ' LOGIC always (loader support)
                movi    ctra, #%0_00001_101     ' PLL, VCO/4
                mov     frqa, frqx              ' 25.175MHz{28.322MHz}

                mov     vscl, #1                ' reload as fast as possible
                mov     zwei, scrn              ' vgrp:mode:vpin:[!Z]:scrn = 2:1:8:5:16 (%%)
                shr     zwei, #5+16             ' |
                or      zwei, #%%000_3          ' |
                mov     vcfg, zwei              ' set vgrp and vpin
                movi    vcfg, #%0_01_0_00_000   ' VGA, 2 colour mode

                test    zwei, #%1_00000000 wz   ' |
        if_nz   xor     rcnt, #16|8             ' blink mode setup (default is 8)

                waitcnt temp, #0                ' PLL settled, frame counter flushed

                ror     vcfg, #1                ' freeze video h/w
                mov     vscl, line              ' transfer user value
                rol     vcfg, #1                ' unfreeze
                waitpne $, #0                   ' get some distance
                waitvid zero, #0                ' latch user value

                and     mask, vcfg              ' transfer vpin
                mov     temp, vcfg              ' |
                shr     temp, #9                ' extract vgrp
                shl     temp, #3                ' 0..3 >> 0..24
                shl     mask, temp              ' finalise mask

                max     dira, mask              ' drive outputs
                mov     $000, pal0              ' restore colour entry 0
                jmp     #vsync                  ' return

' Local data, used only once.

pal0            long    dcolour|hv_idle         ' first palette entry
#ifdef VGA_MODE_720
frqx            long    $16A85879               ' 28.322MHz
#else
frqx            long    $1423D70A               ' 25.175MHz
#endif
mask            long    %11111111

hram            long    $00007FFF               ' hub RAM mask
trap            long    $FFFF8000 +12           ' primary/secondary trap                (##)

EOD{ata}        fit

' uninitialised data and/or temporaries

                org     setup

scrn            res     1                       ' screen buffer         < setup +10     (%%)
font            res     1                       ' font definition       < setup +12     (%%)
locn            res     1                       ' cursor location       < setup +14     (%%)
ecnt            res     1                       ' element count
scnt            res     1                       ' scanlines (per char)

temp            res     alias                   '                       < setup + 8     (%%)
addr            res     1                       ' current screen base
rows            res     1                       ' display row count
crs0            res     1                       ' cursor 0 location and mode
crs1            res     1                       ' cursor 1 location and mode

eins            res     1
zwei            res     1                       '                       < setup < 26    (%%)
vier            res     1

col2            res     alias
col0            res     1
col3            res     alias
col1            res     1

pix             res     80 +1                   ' emitter pixel array |
col             res     80 +1                   ' emitter colour data | + park position

tail            fit

DAT                                             ' translation table

__table         word    (@__names - @__table)/2

                word    res_x
                word    res_y
                word    res_m

__names         byte    "res_x", 0
                byte    "res_y", 0
                byte    "res_m", 0

CON
  zero    = $1F0                                ' par (dst only)
  hv_idle = $01010101 * %10 {%hv}               ' h/v sync inactive
  dcolour = %%0000_0000_0000_0000               ' default colour

  txt_columns = 80                              ' |
  txt_rows    = 25                              ' |
#ifdef VGA_MODE_720
  res_x   = 720                                 ' |
#else
  res_x   = 640                                 ' |
#endif
  res_y   = 400                                 ' |
  res_m   = 4                                   ' UI support

  alias   = 0

DAT

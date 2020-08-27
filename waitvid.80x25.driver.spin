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

  long[mailbox][1] := (16 << 24) | @vga_font
  long[mailbox][3] := 0

  cognew(@driver, mailbox)
  cognew(@driver, mailbox | $8000)

  repeat
  until long[mailbox][3] == $0000FFFF           ' OK (secondary/primary)

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

' horizontal timing 640(640)  1(16) 6(96)  3(48)
'   vertical timing 400(400) 12(12) 2(2)  35(35)

'                               +---------------- front porch
'                               | +-------------- sync
'                               | |    +--------- back porch
'                               | |    |
vsync
                mov     ecnt, #12+2+(35-2)

                cmp     ecnt, #35 wz
        if_ne   cmp     ecnt, #33 wz
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
        if_nz   mov     scrn, temp
        if_nz   wrlong  zero, scrn_             ' acknowledge screen buffer setup
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


blank           mov     vscl, line              ' 256/640
                waitvid sync, #%0000            ' latch blank line
                call    #hsync
blank_ret       ret


chars           movd    :one, #pix+0            ' |
                movd    :two, #col+0            ' restore initial settings
                movs    :two, #pix+0            ' |

                mov     vscl, hvis              ' 1/8, speed up (one pixel per frame clock)
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

wrap            long     16 << 12 | 160         '  16/160
hvis            long      1 << 12 | 8           '   1/8
line            long      0 << 12 | 640         ' 256/640
many            long      0 << 12 | 1600        ' 256/1600

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
                mov     frqa, frqx              ' 25.175MHz

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
frqx            long    $1423D70A               ' 25.175MHz
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

CON
  zero    = $1F0                                ' par (dst only)
  hv_idle = $01010101 * %10 {%hv}               ' h/v sync inactive
  dcolour = %%0000_0000_0000_0000               ' default colour

  res_x   = 640                                 ' |
  res_y   = 400                                 ' |
  res_m   = 4                                   ' UI support

  alias   = 0

DAT

vga_font
                word    $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $FFFF, $0000, $FFFF, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000
                word    $0000, $0000, $0000, $0000, $0018, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000
                word    $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0008, $0000
                word    $000C, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000
                word    $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $001C, $0018, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000
                word    $0000, $0000, $0000, $0000, $0000, $006E, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $2288, $55AA, $EEBB, $1818, $1818, $1818, $6C6C, $0000, $0000, $6C6C, $6C6C, $0000, $6C6C, $6C6C, $1818, $0000
                word    $1818, $1818, $0000, $1818, $0000, $1818, $1818, $6C6C, $6C6C, $0000, $6C6C, $0000, $6C6C, $0000, $6C6C, $1818, $6C6C, $0000, $0000, $6C6C, $1818, $0000, $0000, $6C6C, $1818, $1818, $0000, $FFFF, $0000, $0F0F, $F0F0, $FFFF
                word    $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $1818, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000

                word    $0000, $007E, $007E, $0000, $0000, $0018, $0018, $0000, $FFFF, $0000, $FFFF, $0078, $003C, $00FC, $00FE, $0018, $0001, $0040, $0018, $0066, $00FE, $3E63, $0000, $0018, $0018, $0018, $0000, $0000, $0000, $0000, $0000, $0000
                word    $0000, $0018, $6666, $0036, $183E, $0000, $001C, $0C0C, $0030, $000C, $0000, $0000, $0000, $0000, $0000, $0040, $003E, $0018, $003E, $003E, $0030, $007F, $001C, $007F, $003E, $003E, $0000, $0000, $0060, $0000, $0006, $003E
                word    $003E, $0008, $003F, $003C, $001F, $007F, $007F, $003C, $0063, $003C, $0078, $0067, $000F, $0063, $0063, $001C, $003F, $003E, $003F, $003E, $007E, $0063, $0063, $0063, $0063, $0066, $007F, $003C, $0001, $003C, $1C36, $0000
                word    $0C18, $0000, $0007, $0000, $0038, $0000, $001C, $0000, $0007, $0018, $0060, $0007, $001C, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0008, $0000, $0000, $0000, $0000, $0000, $0000, $0070, $0018, $000E, $006E, $0000
                word    $003C, $0033, $3018, $081C, $0033, $060C, $1C36, $0000, $081C, $0033, $060C, $0066, $183C, $060C, $6363, $361C, $0C06, $0000, $007C, $081C, $0063, $060C, $0C1E, $060C, $0063, $6363, $6363, $1818, $1C36, $0066, $1F33, $70D8
                word    $180C, $3018, $180C, $180C, $006E, $3B00, $3C36, $1C36, $000C, $0000, $0000, $0303, $0303, $0018, $0000, $0000, $2288, $55AA, $EEBB, $1818, $1818, $1818, $6C6C, $0000, $0000, $6C6C, $6C6C, $0000, $6C6C, $6C6C, $1818, $0000
                word    $1818, $1818, $0000, $1818, $0000, $1818, $1818, $6C6C, $6C6C, $0000, $6C6C, $0000, $6C6C, $0000, $6C6C, $1818, $6C6C, $0000, $0000, $6C6C, $1818, $0000, $0000, $6C6C, $1818, $1818, $0000, $FFFF, $0000, $0F0F, $F0F0, $FFFF
                word    $0000, $0000, $007F, $0000, $007F, $0000, $0000, $0000, $007E, $001C, $001C, $0078, $0000, $00C0, $0038, $0000, $0000, $0000, $000C, $0030, $0070, $1818, $0000, $0000, $1C36, $0000, $0000, $F030, $1B36, $0E1B, $0000, $0000

                word    $0000, $81A5, $FFDB, $367F, $081C, $3C3C, $3C7E, $0000, $FFFF, $003C, $FFC3, $7058, $6666, $CCFC, $C6FE, $18DB, $0307, $6070, $3C7E, $6666, $DBDB, $061C, $0000, $3C7E, $3C7E, $1818, $0018, $000C, $0000, $0014, $081C, $7F7F
                word    $0000, $3C3C, $6624, $367F, $6343, $0043, $3636, $0C06, $180C, $1830, $0066, $0018, $0000, $0000, $0000, $6030, $6373, $1C1E, $6360, $6360, $383C, $0303, $0603, $6360, $6363, $6363, $1818, $1818, $3018, $0000, $0C18, $6363
                word    $6363, $1C36, $6666, $6643, $3666, $6646, $6646, $6643, $6363, $1818, $3030, $6636, $0606, $777F, $676F, $3663, $6666, $6363, $6666, $6363, $7E5A, $6363, $6363, $6363, $6336, $6666, $6331, $0C0C, $0307, $3030, $6300, $0000
                word    $0000, $0000, $0606, $0000, $3030, $0000, $3626, $0000, $0606, $1800, $6000, $0606, $1818, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0C0C, $0000, $0000, $0000, $0000, $0000, $0000, $1818, $1818, $1818, $3B00, $0008
                word    $6643, $3300, $0C00, $3600, $3300, $1800, $1C00, $003C, $3600, $3300, $1800, $6600, $6600, $1800, $081C, $001C, $007F, $0033, $3633, $3600, $6300, $1800, $3300, $1800, $6300, $1C36, $0063, $3C66, $2606, $663C, $331F, $1818
                word    $0600, $0C00, $0600, $0600, $3B00, $6367, $367C, $361C, $0C00, $0000, $0000, $6333, $6333, $1800, $006C, $001B, $2288, $55AA, $EEBB, $1818, $1818, $1818, $6C6C, $0000, $0000, $6C6C, $6C6C, $0000, $6C6C, $6C6C, $1818, $0000
                word    $1818, $1818, $0000, $1818, $0000, $1818, $1818, $6C6C, $6C6C, $0000, $6C6C, $0000, $6C6C, $0000, $6C6C, $1818, $6C6C, $0000, $0000, $6C6C, $1818, $0000, $0000, $6C6C, $1818, $1818, $0000, $FFFF, $0000, $0F0F, $F0F0, $FFFF
                word    $0000, $003E, $6363, $007F, $6306, $0000, $0066, $006E, $183C, $3663, $3663, $0C18, $0000, $607E, $0C06, $3E63, $7F00, $1818, $1830, $180C, $D8D8, $1818, $1818, $006E, $361C, $0000, $0000, $3030, $3636, $0C06, $003E, $0000

                word    $0000, $8181, $FFFF, $7F7F, $3E7F, $E7E7, $FFFF, $183C, $E7C3, $6642, $99BD, $4C1E, $663C, $0C0C, $C6C6, $3CE7, $1F7F, $7C7F, $1818, $6666, $DBDE, $3663, $0000, $1818, $1818, $1818, $307F, $067F, $0303, $367F, $1C3E, $3E3E
                word    $0000, $3C18, $0000, $3636, $033E, $6330, $1C6E, $0000, $0C0C, $3030, $3CFF, $187E, $0000, $007F, $0000, $180C, $7B6F, $1818, $3018, $603C, $3633, $033F, $033F, $3018, $633E, $637E, $0000, $0000, $0C06, $7E00, $3060, $3018
                word    $7B7B, $6363, $663E, $0303, $6666, $161E, $161E, $0303, $637F, $1818, $3030, $361E, $0606, $7F6B, $7F7B, $6363, $663E, $6363, $663E, $061C, $1818, $6363, $6363, $636B, $1C1C, $663C, $180C, $0C0C, $0E1C, $3030, $0000, $0000
                word    $0000, $1E30, $1E36, $3E63, $3C36, $3E63, $060F, $6E33, $366E, $1C18, $7060, $6636, $1818, $377F, $3B66, $3E63, $3B66, $6E33, $3B6E, $3E63, $3F0C, $3333, $6666, $6363, $6336, $6363, $7F33, $180E, $1800, $1870, $0000, $1C36
                word    $0303, $3333, $3E63, $1E30, $1E30, $1E30, $1E30, $6606, $3E63, $3E63, $3E63, $1C18, $1C18, $1C18, $3663, $3663, $6606, $6E6C, $337F, $3E63, $3E63, $3E63, $3333, $3333, $6363, $6363, $6363, $0606, $0F06, $187E, $2333, $187E
                word    $1E30, $1C18, $3E63, $3333, $3B66, $6F7F, $007E, $003E, $0C0C, $007F, $007F, $1B0C, $1B0C, $1818, $361B, $366C, $2288, $55AA, $EEBB, $1818, $1818, $1F18, $6C6C, $0000, $1F18, $6F60, $6C6C, $7F60, $6F60, $6C6C, $1F18, $0000
                word    $1818, $1818, $0000, $1818, $0000, $1818, $F818, $6C6C, $EC0C, $FC0C, $EF00, $FF00, $EC0C, $FF00, $EF00, $FF00, $6C6C, $FF00, $0000, $6C6C, $F818, $F818, $0000, $6C6C, $FF18, $1818, $0000, $FFFF, $0000, $0F0F, $F0F0, $FFFF
                word    $6E3B, $633F, $0303, $3636, $0C18, $7E1B, $6666, $3B18, $6666, $637F, $6363, $307C, $7EDB, $DBDB, $063E, $6363, $007F, $7E18, $6030, $060C, $1818, $1818, $007E, $3B00, $0000, $0018, $0000, $3030, $3636, $131F, $3E3E, $0000

                word    $0000, $BD99, $C3E7, $7F3E, $3E1C, $E718, $7E18, $3C18, $C3E7, $4266, $BD99, $3333, $187E, $0C0E, $C6E6, $3CDB, $1F07, $7C70, $187E, $6600, $D8D8, $6336, $007F, $187E, $1818, $187E, $3018, $060C, $037F, $3614, $3E7F, $1C1C
                word    $0000, $1800, $0000, $367F, $6061, $180C, $3B33, $0000, $0C0C, $3030, $3C66, $1818, $0018, $0000, $0000, $0603, $6763, $1818, $0C06, $6060, $7F30, $6060, $6363, $0C0C, $6363, $6060, $0018, $0018, $0C18, $007E, $3018, $1800
                word    $7B3B, $7F63, $6666, $0343, $6666, $1646, $1606, $7B63, $6363, $1818, $3033, $3636, $0646, $6363, $7363, $6363, $0606, $6B7B, $3666, $3063, $1818, $6363, $6336, $6B7F, $1C36, $1818, $0643, $0C0C, $3870, $3030, $0000, $0000
                word    $0000, $3E33, $6666, $0303, $3333, $7F03, $0606, $3333, $6666, $1818, $6060, $1E36, $1818, $6B6B, $6666, $6363, $6666, $3333, $6606, $0E38, $0C0C, $3333, $6666, $6B6B, $1C1C, $6363, $180C, $1818, $1818, $1818, $0000, $6363
                word    $4366, $3333, $7F03, $3E33, $3E33, $3E33, $3E33, $663C, $7F03, $7F03, $7F03, $1818, $1818, $1818, $637F, $637F, $3E06, $7E1B, $3333, $6363, $6363, $6363, $3333, $3333, $6363, $6363, $6363, $663C, $0606, $187E, $7B33, $1818
                word    $3E33, $1818, $6363, $3333, $6666, $7B73, $0000, $0000, $0663, $0303, $6060, $063B, $6673, $3C3C, $366C, $361B, $2288, $55AA, $EEBB, $1818, $1F18, $1F18, $6F6C, $7F6C, $1F18, $6F6C, $6C6C, $6F6C, $7F00, $7F00, $1F00, $1F18
                word    $F800, $FF00, $FF18, $F818, $FF00, $FF18, $F818, $EC6C, $FC00, $EC6C, $FF00, $EF6C, $EC6C, $FF00, $EF6C, $FF00, $FF00, $FF18, $FF6C, $FC00, $F800, $F818, $FC6C, $FF6C, $FF18, $1F00, $F818, $FFFF, $FFFF, $0F0F, $F0F0, $0000
                word    $1B1B, $6363, $0303, $3636, $0C06, $1B1B, $663E, $1818, $663C, $6363, $3636, $6666, $DB7E, $CF7E, $0606, $6363, $0000, $1800, $180C, $1830, $1818, $181B, $0018, $6E3B, $0000, $1800, $1800, $3736, $0000, $0000, $3E3E, $0000

                word    $0000, $817E, $FF7E, $1C08, $0800, $183C, $183C, $0000, $FFFF, $3C00, $C3FF, $331E, $1818, $0F07, $E767, $1818, $0301, $6040, $3C18, $6666, $D8D8, $1C30, $7F7F, $3C18, $1818, $3C18, $0000, $0000, $0000, $0000, $7F00, $0800
                word    $0000, $1818, $0000, $3636, $633E, $6663, $336E, $0000, $1830, $180C, $0000, $0000, $1818, $0000, $1818, $0100, $633E, $187E, $637F, $633E, $3078, $633E, $633E, $0C0C, $633E, $301E, $1800, $180C, $3060, $0000, $0C06, $1818
                word    $033E, $6363, $663F, $663C, $361F, $667F, $060F, $665C, $6363, $183C, $331E, $6667, $667F, $6363, $6363, $361C, $060F, $3E30, $6667, $633E, $183C, $633E, $1C08, $3E36, $6363, $183C, $637F, $0C3C, $6040, $303C, $0000, $0000
                word    $0000, $336E, $663E, $633E, $336E, $633E, $060F, $3E30, $6667, $183C, $6066, $6667, $183C, $6B63, $6666, $633E, $3E06, $3E30, $060F, $633E, $6C38, $336E, $3C18, $7F36, $3663, $7E60, $667F, $1870, $1818, $180E, $0000, $7F00
                word    $3C30, $336E, $633E, $336E, $336E, $336E, $336E, $3060, $633E, $633E, $633E, $183C, $183C, $183C, $6363, $6363, $667F, $1B76, $3373, $633E, $633E, $633E, $336E, $336E, $7E60, $361C, $633E, $1818, $673F, $1818, $3363, $1818
                word    $336E, $183C, $633E, $336E, $6666, $6363, $0000, $0000, $633E, $0300, $6000, $6130, $797C, $3C18, $0000, $0000, $2288, $55AA, $EEBB, $1818, $1818, $1818, $6C6C, $6C6C, $1818, $6C6C, $6C6C, $6C6C, $0000, $0000, $0000, $1818
                word    $0000, $0000, $1818, $1818, $0000, $1818, $1818, $6C6C, $0000, $6C6C, $0000, $6C6C, $6C6C, $0000, $6C6C, $0000, $0000, $1818, $6C6C, $0000, $0000, $1818, $6C6C, $6C6C, $1818, $0000, $1818, $FFFF, $FFFF, $0F0F, $F0F0, $0000
                word    $3B6E, $3F03, $0303, $3636, $637F, $1B0E, $0606, $1818, $187E, $361C, $3677, $663C, $0000, $0603, $0C38, $6363, $7F00, $00FF, $007E, $007E, $1818, $1B0E, $1800, $0000, $0000, $0000, $0000, $3C38, $0000, $0000, $3E00, $0000

                word    $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $FFFF, $0000, $FFFF, $0000, $0000, $0000, $0300, $0000, $0000, $0000, $0000, $0000, $0000, $633E, $0000, $7E00, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000
                word    $0000, $0000, $0000, $0000, $1818, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0C00, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000
                word    $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $7000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $00FF
                word    $0000, $0000, $0000, $0000, $0000, $0000, $0000, $331E, $0000, $0000, $663C, $0000, $0000, $0000, $0000, $0000, $060F, $3078, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $301F, $0000, $0000, $0000, $0000, $0000, $0000
                word    $603E, $0000, $0000, $0000, $0000, $0000, $0000, $3C00, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $301E, $0000, $0000, $0000, $0000, $0000, $0000, $1B0E
                word    $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $187C, $6060, $0000, $0000, $0000, $2288, $55AA, $EEBB, $1818, $1818, $1818, $6C6C, $6C6C, $1818, $6C6C, $6C6C, $6C6C, $0000, $0000, $0000, $1818
                word    $0000, $0000, $1818, $1818, $0000, $1818, $1818, $6C6C, $0000, $6C6C, $0000, $6C6C, $6C6C, $0000, $6C6C, $0000, $0000, $1818, $6C6C, $0000, $0000, $1818, $6C6C, $6C6C, $1818, $0000, $1818, $FFFF, $FFFF, $0F0F, $F0F0, $0000
                word    $0000, $0302, $0000, $0000, $0000, $0000, $0300, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $1818, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000

                word    $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $FFFF, $0000, $FFFF, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000
                word    $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000
                word    $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000
                word    $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000
                word    $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000
                word    $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $2288, $55AA, $EEBB, $1818, $1818, $1818, $6C6C, $6C6C, $1818, $6C6C, $6C6C, $6C6C, $0000, $0000, $0000, $1818
                word    $0000, $0000, $1818, $1818, $0000, $1818, $1818, $6C6C, $0000, $6C6C, $0000, $6C6C, $6C6C, $0000, $6C6C, $0000, $0000, $1818, $6C6C, $0000, $0000, $1818, $6C6C, $6C6C, $1818, $0000, $1818, $FFFF, $FFFF, $0F0F, $F0F0, $0000
                word    $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $1818, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000

''
'' VGA display 80x25 (dual cog) - video driver and pixel generator
''
''        Author: Marko Lukat
'' Last modified: 2018/12/10
''       Version: 0.15.nine.7
''
'' long[par][0]: vgrp:[!Z]:vpin:[!Z]:addr = 2:1:8:5:16 -> zero (accepted) screen buffer    (4n)
'' long[par][1]:                addr:addr =      16:16 -> zero (accepted) palette/font     (2n/4n)
'' long[par][2]:                addr:addr =      16:16 -> zero (accepted) cursor locations (4n)
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
''
'' 20181124: dropped character blink mode, now uses 256 entry (hub) palette
'' 20181127: full 9x16 support
'' 20181129: clean palette before use
'' 20181206: re-introduced blink attribute
''
'' 20181210: added palette data (M. Maccaferri)
'' 20181210: allow screen buffer switch (M. Maccaferri)
'' 20181210: modified cursor code to modify pixels only (M. Maccaferri)
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

PUB init(ID, mailbox) : cog

  long[mailbox][1] := (@palette << 16) | @vga_font
  long[mailbox][3] := 0

  cognew(@driver, mailbox)
  cognew(@driver, mailbox | $8000)

  repeat
  until long[mailbox][3] == $0000FFFF           ' OK (secondary/primary)

  long[mailbox][3] := 0                         ' release sync lock

DAT
'
' Each of the 256 (word) palette entries holds FG colour in the high and BG colour in the low byte. Bits 1, 8 and 9 are unused and should be 0.
' Bit 0 defines whether this colour should blink (1) or not (0). IOW, if the blink attribute is not required all 256 entries are available for
' user defined colour pairs.
'
' For a setup which requires a blink attribute (see below) each colour is doubled (2n: colour|%%0, 2n+1: colour|%%1), e.g.
'
'   colour format: %FFFF_BBB_A
'
'     FFFF: foreground index
'      BBB: background index
'        A: blink mode (0/1 = off/on)
'
palette
                word    %%000_0_000_0, %%000_0_000_1, %%000_0_200_0, %%000_0_200_1, %%000_0_020_0, %%000_0_020_1, %%000_0_220_0, %%000_0_220_1
                word    %%000_0_002_0, %%000_0_002_1, %%000_0_202_0, %%000_0_202_1, %%000_0_022_0, %%000_0_022_1, %%000_0_222_0, %%000_0_222_1
                word    %%200_0_000_0, %%200_0_000_1, %%200_0_200_0, %%200_0_200_1, %%200_0_020_0, %%200_0_020_1, %%200_0_220_0, %%200_0_220_1
                word    %%200_0_002_0, %%200_0_002_1, %%200_0_202_0, %%200_0_202_1, %%200_0_022_0, %%200_0_022_1, %%200_0_222_0, %%200_0_222_1
                word    %%020_0_000_0, %%020_0_000_1, %%020_0_200_0, %%020_0_200_1, %%020_0_020_0, %%020_0_020_1, %%020_0_220_0, %%020_0_220_1
                word    %%020_0_002_0, %%020_0_002_1, %%020_0_202_0, %%020_0_202_1, %%020_0_022_0, %%020_0_022_1, %%020_0_222_0, %%020_0_222_1
                word    %%220_0_000_0, %%220_0_000_1, %%220_0_200_0, %%220_0_200_1, %%220_0_020_0, %%220_0_020_1, %%220_0_220_0, %%220_0_220_1
                word    %%220_0_002_0, %%220_0_002_1, %%220_0_202_0, %%220_0_202_1, %%220_0_022_0, %%220_0_022_1, %%220_0_222_0, %%220_0_222_1
                word    %%002_0_000_0, %%002_0_000_1, %%002_0_200_0, %%002_0_200_1, %%002_0_020_0, %%002_0_020_1, %%002_0_220_0, %%002_0_220_1
                word    %%002_0_002_0, %%002_0_002_1, %%002_0_202_0, %%002_0_202_1, %%002_0_022_0, %%002_0_022_1, %%002_0_222_0, %%002_0_222_1
                word    %%202_0_000_0, %%202_0_000_1, %%202_0_200_0, %%202_0_200_1, %%202_0_020_0, %%202_0_020_1, %%202_0_220_0, %%202_0_220_1
                word    %%202_0_002_0, %%202_0_002_1, %%202_0_202_0, %%202_0_202_1, %%202_0_022_0, %%202_0_022_1, %%202_0_222_0, %%202_0_222_1
                word    %%022_0_000_0, %%022_0_000_1, %%022_0_200_0, %%022_0_200_1, %%022_0_020_0, %%022_0_020_1, %%022_0_220_0, %%022_0_220_1
                word    %%022_0_002_0, %%022_0_002_1, %%022_0_202_0, %%022_0_202_1, %%022_0_022_0, %%022_0_022_1, %%022_0_222_0, %%022_0_222_1
                word    %%222_0_000_0, %%222_0_000_1, %%222_0_200_0, %%222_0_200_1, %%222_0_020_0, %%222_0_020_1, %%222_0_220_0, %%222_0_220_1
                word    %%222_0_002_0, %%222_0_002_1, %%222_0_202_0, %%222_0_202_1, %%222_0_022_0, %%222_0_022_1, %%222_0_222_0, %%222_0_222_1
                word    %%111_0_000_0, %%111_0_000_1, %%111_0_200_0, %%111_0_200_1, %%111_0_020_0, %%111_0_020_1, %%111_0_220_0, %%111_0_220_1
                word    %%111_0_002_0, %%111_0_002_1, %%111_0_202_0, %%111_0_202_1, %%111_0_022_0, %%111_0_022_1, %%111_0_222_0, %%111_0_222_1
                word    %%300_0_000_0, %%300_0_000_1, %%300_0_200_0, %%300_0_200_1, %%300_0_020_0, %%300_0_020_1, %%300_0_220_0, %%300_0_220_1
                word    %%300_0_002_0, %%300_0_002_1, %%300_0_202_0, %%300_0_202_1, %%300_0_022_0, %%300_0_022_1, %%300_0_222_0, %%300_0_222_1
                word    %%030_0_000_0, %%030_0_000_1, %%030_0_200_0, %%030_0_200_1, %%030_0_020_0, %%030_0_020_1, %%030_0_220_0, %%030_0_220_1
                word    %%030_0_002_0, %%030_0_002_1, %%030_0_202_0, %%030_0_202_1, %%030_0_022_0, %%030_0_022_1, %%030_0_222_0, %%030_0_222_1
                word    %%331_0_000_0, %%331_0_000_1, %%331_0_200_0, %%331_0_200_1, %%331_0_020_0, %%331_0_020_1, %%331_0_220_0, %%331_0_220_1
                word    %%331_0_002_0, %%331_0_002_1, %%331_0_202_0, %%331_0_202_1, %%331_0_022_0, %%331_0_022_1, %%331_0_222_0, %%331_0_222_1
                word    %%003_0_000_0, %%003_0_000_1, %%003_0_200_0, %%003_0_200_1, %%003_0_020_0, %%003_0_020_1, %%003_0_220_0, %%003_0_220_1
                word    %%003_0_002_0, %%003_0_002_1, %%003_0_202_0, %%003_0_202_1, %%003_0_022_0, %%003_0_022_1, %%003_0_222_0, %%003_0_222_1
                word    %%303_0_000_0, %%303_0_000_1, %%303_0_200_0, %%303_0_200_1, %%303_0_020_0, %%303_0_020_1, %%303_0_220_0, %%303_0_220_1
                word    %%303_0_002_0, %%303_0_002_1, %%303_0_202_0, %%303_0_202_1, %%303_0_022_0, %%303_0_022_1, %%303_0_222_0, %%303_0_222_1
                word    %%033_0_000_0, %%033_0_000_1, %%033_0_200_0, %%033_0_200_1, %%033_0_020_0, %%033_0_020_1, %%033_0_220_0, %%033_0_220_1
                word    %%033_0_002_0, %%033_0_002_1, %%033_0_202_0, %%033_0_202_1, %%033_0_022_0, %%033_0_022_1, %%033_0_222_0, %%033_0_222_1
                word    %%333_0_000_0, %%333_0_000_1, %%333_0_200_0, %%333_0_200_1, %%333_0_020_0, %%333_0_020_1, %%333_0_220_0, %%333_0_220_1
                word    %%333_0_002_0, %%333_0_002_1, %%333_0_202_0, %%333_0_202_1, %%333_0_022_0, %%333_0_022_1, %%333_0_222_0, %%333_0_222_1

DAT             org     0                       ' video driver

driver          jmpret  $, #setup               '  -4   once

' horizontal timing 720(720)  1(18) 6(108) 3(54)
'   vertical timing 400(400) 13(13) 2(2)  34(34)

'                               +---------------- front porch
'                               | +-------------- sync
'                               | |    +--------- back porch
'                               | |    |
vsync           mov     ecnt, #13+2+(34-4)

                cmp     ecnt, #32 wz
        if_ne   cmp     ecnt, #30 wz
        if_e    xor     sync, #$0101            ' in/active

                call    #blank
                djnz    ecnt, #vsync+1

' While still in sync, figure out the blink state (used to be based on cnt) and cursor.
' hsync offers 31 hub windows.

                add     fcnt, #1                ' next frame
                cmpsub  fcnt, #36 wz            ' N frames per phase (on/off)
        if_z    rev     rcnt, #{32-}0           ' $F80000_00 vs $000000_1F; 70/(2*36), ~1Hz

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

                mov     ecnt, #4
        if_nc   call    #blank                  ' |
        if_nc   djnz    ecnt, #$-1              ' back porch remainder (primary only)

' Vertical sync chain done, do visible area.

                mov     zwei, scrn              ' screen base address
                mov     rows, #res_y/16         ' row count

:scan           mov     scnt, #16/4/2           ' 16 quad scanlines (split between primary and secondary)
                mov     eins, font              ' font base
        if_nc   add     eins, adv4              ' interleaved

:line           mov     vscl, many              ' four lines we don't use
                waitvid zero, #0                ' 635 hub windows

                call    #load                   ' load pixels and colours for the next four lines

                call    #chars                  ' |
                call    #chars                  ' |
                call    #chars                  ' display scanlines
                call    #char3                  ' |

                add     eins, adv8              ' skip 8 scanlines
                djnz    scnt, #:line            ' for all character scanlines
                sub     zwei, #80*2             ' next row
                djnz    rows, #:scan            ' for all rows

                mov     ecnt, #4
        if_c    call    #blank                  ' secondary finishes early so
        if_c    djnz    ecnt, #$-1              ' let him do some blank lines

        if_nc   wrlong  cnt, fcnt_              ' announce vertical blank (primary)

                jmp     #vsync                  ' next frame


blank           mov     vscl, line              ' 180/720
                waitvid sync, #%0000            ' latch blank line
                call    #hsync
blank_ret       ret


chars           movd    :one, #pix-1            ' |
                movs    :two, #pix+0            ' |
                movd    :two, #col+0            ' restore initial settings

                mov     vscl, hvis              ' 1/9, speed up (one pixel per frame clock)
                mov     ecnt, #80               ' character count

:loop           add     :one, dst1              ' advance
                add     :two, d1s1              ' advance (pipeline)
:two            waitvid 0-0, 1-1                ' emit pixels
:one            ror     1-1, #10                ' %%0_cCCCC_bBBBB_aAAAA
                djnz    ecnt, #:loop

' Horizontal sync embedded here due to timing constraints, only 18 clocks are allowed between waitvids.

hsync           mov     vscl, wrap              ' |
                waitvid sync, #%0001111110      ' horizontal sync pulse (1/6/3 reverse)
                mov     cnt, cnt                ' record sync point
hsync_ret
chars_ret       ret


char3           movs    :two, #pix-80           ' |
                movd    :two, #col+0            ' restore initial settings

                mov     vscl, hvis              ' 1/9, speed up (one pixel per frame clock)
                mov     ecnt, #80               ' character count

:loop           add     :two, d1s1              ' advance (pipeline)
:two            waitvid 0-0, 1-1                ' emit pixels
                djnz    ecnt, #:loop

                call    #hsync
char3_ret       ret


load            muxnc   flag, $                 ' preserve carry flag

                movd    :pix0_0, #pix+0         ' |
                movd    :pix3_0, #pix-80        ' re/store initial settings
                movd    :colN_0, #col+0         ' |

                movd    :pix0_1, #pix+1         ' |
                movd    :pix3_1, #pix-79        ' |
                movd    :colN_1, #col+1         ' |

                mov     drei, dst2              ' |
                add     drei, eins              ' tail font address (+1024)

                mov     addr, zwei              ' current screen base
                mov     ecnt, #40               ' loop counter

' Fetch pixel data and colour.

:loop           rdword  frqb, addr      {hub}   '  +0 = read ASCII + colour

                ror     frqb, #7                '  +8   ASCII *2 +{0..1}
                mov     phsb, eins              '  -4   current font address
                rdlong  pix0, phsb      {hub}   '  +0 = three scanlines + 1 pixel

                ror     frqb, #1                '  +8   ASCII *1
                add     frqb, drei              '  -4   font tail address
                rdbyte  pix3, frqb      {hub}   '  +0 = remaining 8 pixels

                shr     frqb, #24               '  +8   palette index
                mov     phsb, plte              '  -4   current palette location
                rdword  colN, phsb      {hub}   '  +0 = read palette entry

                sub     addr, #2                '  +8   advance source
                test    colN, #1 wz             '  -4   check mode
                shr     pix0, #1 wc             '  +0 = extract top pixel
                muxc    pix3, #$100             '  +4   insert top pixel

        if_nz   shr     pix0, rcnt              '  +8   1: modify foreground (0/31)
        if_nz   shr     pix3, rcnt              '  -4   1: modify foreground (0/31)

                and     colN, cmsk              '  +0 = clean sync bits
                or      colN, idle              '  +4   insert idle state

:pix0_0         mov     0-0, pix0               '  +8   store scanlines 0..2
                add     $-1, dst2               '  -4   |
:pix3_0         mov     1-1, pix3               '  +0 = store scanline 3
                add     $-1, dst2               '  +4   |
:colN_0         mov     2-2, colN               '  +8   store palette
                add     $-1, dst2               '  -4   |

                rdword  frqb, addr      {hub}   '  +0 =

                ror     frqb, #7                '  +8
                mov     phsb, eins              '  -4
                rdlong  pix0, phsb      {hub}   '  +0 =

                ror     frqb, #1                '  +8
                add     frqb, drei              '  -4
                rdbyte  pix3, frqb      {hub}   '  +0 =

                shr     frqb, #24               '  +8
                mov     phsb, plte              '  -4
                rdword  colN, phsb      {hub}   '  +0 =

                sub     addr, #2                '  +8
                test    colN, #1 wz             '  -4
                shr     pix0, #1 wc             '  +0 =
                muxc    pix3, #$100             '  +4

        if_nz   shr     pix0, rcnt              '  +8
        if_nz   shr     pix3, rcnt              '  -4

                and     colN, cmsk              '  +0 =
                or      colN, idle              '  +4

:pix0_1         mov     0-0, pix0               '  +8
                add     $-1, dst2               '  -4
:pix3_1         mov     1-1, pix3               '  +0 =
                add     $-1, dst2               '  +4
:colN_1         mov     2-2, colN               '  +8
                add     $-1, dst2               '  -4

                djnz    ecnt, #:loop            '  +0 = for all characters

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

                muxc    :set1, #1               ' adjust source
                muxc    :set2, #1

                ror     vier, #8 wc             ' carry: blink on/off
                movd    :set1, vier
                sub     vier, #80
                movd    :set2, vier
        if_c    cmp     fcnt, #18 wc            ' 70/(2*18), ~2Hz
:set1   if_nc   xor     0-0, pmsk{2n}           ' cmsk: block
                                                ' pmsk: underscore
:set2   if_nc   xor     0-0, pmsk{2n}           ' cmsk: block
                                                ' pmsk: underscore
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

rcnt            long    $0000001F               ' bit shift for blink mode
fcnt            long    0                       ' blink frame count
adv4            long    256*(4+1)*1             ' 4 scanlines in font
adv8            long    256*(4+1)*2             ' 8 scanlines in font

flag            long    0                       ' loader flag storage
idle            long    hv_idle
sync            long    hv_idle ^ $0200

wrap            long     18 << 12 | 180         '  18/180
hvis            long      1 << 12 | 9           '   1/9
line            long    180 << 12 | 720         ' 180/720
many            long      0 << 12 | 3600        ' 256/3600

scrn_           long    $00000000 -12           ' |
font_           long    $00000004 -12           ' |
locn_           long    $00000008 -12           ' |
fcnt_           long    $0000000C -12           ' mailbox addresses (local copy)        (##)

dst1            long    1 << 9                  ' dst     +/-= 1
dst2            long    2 << 9                  ' dst     +/-= 2
d1s1            long    1 << 9  | 1             ' dst/src +/-= 1

cmsk            long    %%3330_3330             ' color mask

                long    0[$&1]
pmsk    {2n}    long    %%0_13333_13333_13333   ' xor mask for block cursor
pmsk1   {2n+1}  long    %%0_13333_13333_13333   ' xor mask for underscore cursor (updated for secondary)

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

                mov     plte, font              ' get palette location (2n)             (%%)
                shr     plte, #16               ' |

                rdlong  locn, locn_ wz          ' get cursor location                   (%%)
                and     font, $+1               ' |
                long    $0000FFFC               ' cleanup
        if_nz   wrlong  zero, locn_             ' acknowledge cursor location

' Perform pending setup.

                add     scrn, $+1               ' scrn now points to last word
                long    160*25 -2

' Upset video h/w and relatives.

                rdlong  temp, #0                ' clkfreq
                shr     temp, #10               ' ~1ms
        if_nc   waitpne $, #0                   ' adjust primary

'   primary: cnt + 0 + 6
' secondary: cnt + 2 + 4

                add     temp, cnt

                movi    ctrb, #%0_11111_000     ' LOGIC always (loader support)
                movi    ctra, #%0_00001_101     ' PLL, VCO/4
                mov     frqa, frqx              ' 28.322MHz

                mov     vscl, #1                ' reload as fast as possible
                mov     zwei, scrn              ' vgrp:[!Z]:vpin:[!Z]:scrn = 2:1:8:5:16 (%%)
                shr     zwei, #5+16             ' |
                or      zwei, #%%000_3          ' |
                mov     vcfg, zwei              ' set vgrp and vpin
                movi    vcfg, #%0_01_0_00_000   ' VGA, 2 colour mode

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
        if_c    mov     pmsk1, #0               ' no cursor mask for secondary

' Setup complete, do the heavy lifting upstairs ...

                jmp     %%0                     ' return

' Local data, used only once.

frqx            long    $16A85879               ' 28.322MHz
mask            long    %11111111

hram            long    $00007FFF               ' hub RAM mask
trap            long    $FFFF8000 +12           ' primary/secondary trap                (##)

EOD{ata}        fit

' uninitialised data and/or temporaries

                org     setup

scrn            res     1                       ' screen buffer         < setup +10     (%%)
font            res     1                       ' font definition       < setup +12     (%%)
plte            res     1                       ' palette location      < setup +14     (%%)
locn            res     1                       ' cursor location       < setup +16     (%%)
ecnt            res     1                       ' element count
scnt            res     1                       ' scanlines (per char)

temp            res     alias                   '                       < setup + 8     (%%)
addr            res     1                       ' current screen base
rows            res     1                       ' display row count
crs0            res     1                       ' cursor 0 location and mode
crs1            res     1                       ' cursor 1 location and mode

eins            res     1
zwei            res     1                       '                       < setup +30     (%%)
drei            res     1
vier            res     1

pix0            res     1
pix3            res     1
colN            res     1

                res     80                      ' |
pix             res     80 +1                   ' emitter pixel array |
col             res     80 +1                   ' emitter colour data | + park position

tail            fit

CON
  zero    = $1F0                                ' par (dst only)
  hv_idle = $01010101 * %10 {%hv}               ' h/v sync inactive

  res_x   = 720                                 ' |
  res_y   = 400                                 ' |
  res_m   = 4                                   ' UI support

  alias   = 0

DAT

vga_font
                long    $00000000, $0FC00000, $0FC00000, $00000000, $00000000, $00000000, $00000000, $00000000
                long    $1FE7F9FE, $00000000, $1FE7F9FE, $0F000000, $07800000, $1F800000, $1FC00000, $00000000
                long    $00600800, $0C020000, $03000000, $0CC00000, $1FC00000, $0C61F000, $00000000, $03000000
                long    $03000000, $03000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000
                long    $00000000, $03000000, $0CC33000, $00000000, $07C0C030, $00000000, $03800000, $01806000
                long    $06000000, $01800000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000
                long    $07800000, $03000000, $07C00000, $07C00000, $06000000, $0FE00000, $03800000, $0FE00000
                long    $07C00000, $07C00000, $00000000, $00000000, $00000000, $00000000, $00000000, $07C00000
                long    $00000000, $01000000, $07E00000, $07800000, $03E00000, $0FE00000, $0FE00000, $07800000
                long    $0C600000, $07800000, $0F000000, $0CE00000, $01E00000, $18600000, $0C600000, $07C00000
                long    $07E00000, $07C00000, $07E00000, $07C00000, $1FE00000, $0C600000, $18600000, $18600000
                long    $18600000, $18600000, $1FE00000, $07800000, $00000000, $07800000, $06C0E010, $00000000
                long    $03006018, $00000000, $00E00000, $00000000, $07000000, $00000000, $03800000, $00000000
                long    $00E00000, $03000000, $0C000000, $00E00000, $03800000, $00000000, $00000000, $00000000
                long    $00000000, $00000000, $00000000, $00000000, $01000000, $00000000, $00000000, $00000000
                long    $00000000, $00000000, $00000000, $0E000000, $03000000, $01C00000, $0DC00000, $00000000
                long    $07800000, $06600000, $03018000, $03804000, $06600000, $01803000, $06C0E000, $00000000
                long    $03804000, $0C600000, $01803000, $0CC00000, $0780C000, $01803000, $00031800, $0381B038
                long    $00C06030, $00000000, $0F800000, $03804000, $0C600000, $01803000, $03C06000, $01803000
                long    $0C600000, $00031800, $00031800, $0300C000, $06C0E000, $18600000, $0CC1F800, $1B038000
                long    $0180C000, $03018000, $0180C000, $0180C000, $0DC00000, $0001D8DC, $06C1E000, $06C0E000
                long    $01800000, $00000000, $00000000, $00601800, $00601800, $03000000, $00000000, $00000000
                long    $11011110, $1542A954, $17677176, $0300C030, $0300C030, $0300C030, $0D8360D8, $00000000
                long    $00000000, $0D8360D8, $0D8360D8, $00000000, $0D8360D8, $0D8360D8, $0300C030, $00000000
                long    $0300C030, $0300C030, $00000000, $0300C030, $00000000, $0300C030, $0300C030, $0D8360D8
                long    $0D8360D8, $00000000, $0D8360D8, $00000000, $0D8360D8, $00000000, $0D8360D8, $0300C030
                long    $0D8360D8, $00000000, $00000000, $0D8360D8, $0300C030, $00000000, $00000000, $0D8360D8
                long    $0300C030, $0300C030, $00000000, $3FEFFBFF, $00000000, $01E0781E, $3E0F83E1, $3FEFFBFF
                long    $00000000, $03C00000, $0FE00000, $00000000, $00000000, $00000000, $00000000, $00000000
                long    $00000000, $00000000, $03800000, $0F000000, $00000000, $00000000, $07000000, $00000000
                long    $00000000, $00000000, $00000000, $00000000, $0E000000, $0300C030, $00000000, $00000000
                long    $06C0E000, $00000000, $00000000, $06078000, $06C0D800, $03607000, $00000000, $00000000

                byte    $00, $81, $FF, $00, $00, $18, $18, $00, $FF, $00, $FF, $70, $66, $CC, $C6, $18
                byte    $07, $70, $3C, $66, $DB, $06, $00, $3C, $3C, $18, $00, $00, $00, $00, $00, $00
                byte    $00, $3C, $66, $36, $63, $00, $36, $0C, $18, $18, $00, $00, $00, $00, $00, $00
                byte    $66, $1C, $63, $63, $38, $03, $06, $63, $63, $63, $00, $00, $60, $00, $06, $63
                byte    $3E, $1C, $66, $66, $36, $66, $66, $66, $63, $18, $30, $66, $06, $E7, $67, $63
                byte    $66, $63, $66, $63, $DB, $63, $C3, $C3, $C3, $C3, $C3, $0C, $01, $30, $63, $00
                byte    $00, $00, $06, $00, $30, $00, $36, $00, $06, $18, $60, $06, $18, $00, $00, $00
                byte    $00, $00, $00, $00, $0C, $00, $00, $00, $00, $00, $00, $18, $18, $18, $3B, $00
                byte    $66, $00, $0C, $36, $00, $18, $1C, $00, $36, $00, $18, $00, $66, $18, $08, $00
                byte    $00, $00, $36, $36, $00, $18, $33, $18, $00, $3E, $63, $7E, $26, $66, $66, $18
                byte    $06, $0C, $06, $06, $3B, $63, $36, $36, $0C, $00, $00, $43, $43, $18, $00, $00
                byte    $22, $55, $EE, $18, $18, $18, $6C, $00, $00, $6C, $6C, $00, $6C, $6C, $18, $00
                byte    $18, $18, $00, $18, $00, $18, $18, $6C, $6C, $00, $6C, $00, $6C, $00, $6C, $18
                byte    $6C, $00, $00, $6C, $18, $00, $00, $6C, $18, $18, $00, $FF, $00, $0F, $F0, $FF
                byte    $00, $33, $63, $00, $7F, $00, $00, $00, $7E, $1C, $36, $0C, $00, $C0, $0C, $3E
                byte    $00, $00, $0C, $30, $D8, $18, $00, $00, $36, $00, $00, $30, $36, $0C, $00, $00

                long    $00000000, $1024094A, $1FE7F9B6, $0FE3F86C, $07C0E010, $1CE1E078, $1FE3F078, $03000000
                long    $1CE7F9FE, $0CC1E000, $132619FE, $03C260B0, $0CC330CC, $018061F8, $18C631FC, $0786D830
                long    $0FE0F81E, $0FE3E0F0, $0300C0FC, $0CC330CC, $1BC6D9B6, $0C61B038, $00000000, $0300C0FC
                long    $0300C0FC, $0300C030, $0600C000, $00C06000, $00600000, $0CC12000, $0380E010, $07C3F8FE
                long    $00000000, $0301E078, $00000048, $06C3F86C, $07C01886, $06031886, $0DC0E06C, $0000000C
                long    $01806018, $06018060, $07833000, $0300C000, $00000000, $00000000, $00000000, $06030080
                long    $1B661986, $0300C03C, $030180C0, $078300C0, $0661B078, $07E01806, $07E01806, $060300C0
                long    $07C318C6, $0FC318C6, $0000C030, $0000C030, $0180C060, $0003F000, $0600C018, $030180C6
                long    $0F6318C6, $0C63186C, $07C330CC, $00601886, $0CC330CC, $03C0B08C, $03C0B08C, $00601886
                long    $0FE318C6, $0300C030, $06018060, $03C1B0CC, $00C0300C, $1B67F9FE, $0F63F8DE, $0C6318C6
                long    $07C330CC, $0C6318C6, $07C330CC, $038030C6, $0300C132, $0C6318C6, $18661986, $18661986
                long    $0301E0CC, $07833186, $030180C2, $01806018, $01C03806, $06018060, $00000000, $00000000
                long    $00000000, $0600F000, $06C0F00C, $0C61F000, $06C1E060, $0C61F000, $01E0304C, $06637000
                long    $0DC1B00C, $0300E000, $0C038000, $06C3300C, $0300C030, $1FE33800, $0CC1D800, $0C61F000
                long    $0CC1D800, $06637000, $0DC1D800, $0C61F000, $0181F818, $06619800, $18661800, $18661800
                long    $0CC61800, $0C631800, $0663F800, $01C0C030, $0000C030, $0E00C030, $00000000, $06C0E010
                long    $00601886, $06619800, $0C61F000, $0600F000, $0600F000, $0600F000, $0600F000, $00C33078
                long    $0C61F000, $0C61F000, $0C61F000, $0300E000, $0300E000, $0300E000, $0C61B038, $0C61B038
                long    $00C330FE, $1B83B000, $0FE19866, $0C61F000, $0C61F000, $0C61F000, $06619800, $06619800
                long    $0C631800, $0C6318C6, $0C6318C6, $00601986, $00C0780C, $1FE0C078, $0CC2307C, $0FC0C030
                long    $0600F000, $0300E000, $0C61F000, $06619800, $0CC1D800, $0FE378CE, $0FC000F8, $07C00038
                long    $01806000, $0FE00000, $0FE00000, $030198C6, $030198C6, $0300C000, $06C36000, $06C0D800
                long    $11011110, $1542A954, $17677176, $0300C030, $0300C030, $0300F830, $0D8360D8, $00000000
                long    $0300F800, $0C0378D8, $0D8360D8, $0C03F800, $0C0378D8, $0D8360D8, $0300F830, $00000000
                long    $0300C031, $0300C031, $00000001, $0300C031, $00000001, $0300C031, $030FC031, $0D8360D9
                long    $018F60D9, $018FE001, $000F78D9, $000FF801, $018F60D9, $000FF801, $000F78D9, $000FF831
                long    $0D8360D9, $000FF801, $00000001, $0D8360D9, $030FC031, $030FC001, $00000001, $0D8360D9
                long    $030FF831, $0300C030, $00000001, $3FEFFBFF, $00000001, $01E0781E, $3E0F83E1, $3FEFFBFE
                long    $07637000, $03619866, $006018C6, $06C1B0FE, $018030C6, $0363F000, $0CC330CC, $0301D8DC
                long    $0CC1E030, $0C63186C, $0C6318C6, $0F818030, $1B63F000, $1B63F0C0, $07C0300C, $0C6318C6
                long    $000000FE, $0FC0C030, $0C018030, $00C06030, $0300C1B0, $0300C030, $0000C030, $07637000
                long    $00000038, $00000000, $00000000, $06018060, $06C1B06C, $03E0980C, $07C1F07C, $00000000

                byte    $00, $BD, $C3, $7F, $7F, $E7, $FF, $3C, $C3, $42, $BD, $33, $3C, $0C, $C6, $E7
                byte    $1F, $7C, $18, $66, $D8, $63, $00, $18, $18, $18, $7F, $7F, $03, $FF, $3E, $3E
                byte    $00, $18, $00, $36, $60, $18, $3B, $00, $0C, $30, $FF, $7E, $00, $7F, $00, $18
                byte    $DB, $18, $0C, $60, $7F, $60, $63, $18, $63, $60, $00, $00, $06, $00, $60, $18
                byte    $7B, $7F, $66, $03, $66, $16, $16, $7B, $63, $18, $30, $1E, $06, $C3, $73, $63
                byte    $06, $63, $36, $30, $18, $63, $C3, $DB, $18, $18, $0C, $0C, $1C, $30, $00, $00
                byte    $00, $3E, $66, $03, $33, $7F, $06, $33, $66, $18, $60, $1E, $18, $DB, $66, $63
                byte    $66, $33, $66, $06, $0C, $33, $C3, $C3, $3C, $63, $18, $18, $18, $18, $00, $63
                byte    $03, $33, $7F, $3E, $3E, $3E, $3E, $06, $7F, $7F, $7F, $18, $18, $18, $63, $63
                byte    $3E, $D8, $33, $63, $63, $63, $33, $33, $63, $63, $63, $03, $06, $18, $F6, $18
                byte    $3E, $18, $63, $33, $66, $7B, $00, $00, $06, $03, $60, $0C, $0C, $18, $1B, $6C
                byte    $22, $55, $EE, $18, $1F, $1F, $6F, $7F, $1F, $6F, $6C, $6F, $7F, $7F, $1F, $1F
                byte    $F8, $FF, $FF, $F8, $FF, $FF, $F8, $EC, $FC, $EC, $FF, $EF, $EC, $FF, $EF, $FF
                byte    $FF, $FF, $FF, $FC, $F8, $F8, $FC, $FF, $FF, $1F, $F8, $FF, $FF, $0F, $F0, $00
                byte    $1B, $33, $03, $36, $18, $1B, $66, $18, $66, $7F, $36, $66, $DB, $DB, $06, $63
                byte    $7F, $18, $30, $0C, $18, $18, $7E, $00, $00, $18, $00, $37, $00, $00, $3E, $00

                long    $00000000, $10240932, $1FE7F9CE, $0381F0FE, $0100E07C, $0300C1CE, $0300C0FC, $0000C078
                long    $1FE73986, $07833084, $1864C97A, $06619866, $0303F030, $01E07018, $1CE7318C, $0306D878
                long    $0060381E, $0C0380F0, $0301E0FC, $0CC000CC, $1B06C1B0, $0600E06C, $0FE3F8FE, $0301E0FC
                long    $0300C030, $0783F030, $0000C060, $0000600C, $0003F806, $000120CC, $0FE3F87C, $0100E038
                long    $00000000, $03000030, $00000000, $06C3F86C, $0C6308C0, $0C603018, $06619866, $00000000
                long    $03006018, $03018060, $00033078, $0000C030, $0300C000, $00000000, $03000000, $00603018
                long    $0CC61986, $0300C030, $0C60180C, $0C6300C0, $06018060, $0C6300C0, $0C6318C6, $01806018
                long    $0C6318C6, $060300C0, $0300C000, $0300C000, $0600C018, $000000FC, $0180C060, $03000030
                long    $0061D8F6, $0C6318C6, $0CC330CC, $0CC21806, $06C330CC, $0CC2300C, $00C0300C, $0CC318C6
                long    $0C6318C6, $0300C030, $06619866, $0CC3306C, $0CC2300C, $18661986, $0C6318C6, $0C6318C6
                long    $00C0300C, $0F6358C6, $0CC330CC, $0C6318C0, $0300C030, $0C6318C6, $07833186, $0CC7F9B6
                long    $18633078, $0300C030, $1864180C, $01806018, $0C038070, $06018060, $00000000, $00000000
                long    $00000000, $06619866, $0CC330CC, $0C601806, $06619866, $0C601806, $00C0300C, $06619866
                long    $0CC330CC, $0300C030, $0C0300C0, $0CC1B03C, $0300C030, $1B66D9B6, $0CC330CC, $0C6318C6
                long    $0CC330CC, $06619866, $00C0300C, $0C618038, $0D806018, $06619866, $07833186, $1FE6D9B6
                long    $0CC1E030, $0C6318C6, $0C603018, $0300C030, $0300C030, $0300C030, $00000000, $0FE318C6
                long    $07833086, $06619866, $0C601806, $06619866, $06619866, $06619866, $06619866, $0601E0CC
                long    $0C601806, $0C601806, $0C601806, $0300C030, $0300C030, $0300C030, $0C6318FE, $0C6318FE
                long    $0CC0300C, $0760D8FC, $06619866, $0C6318C6, $0C6318C6, $0C6318C6, $06619866, $06619866
                long    $0C6318C6, $0C6318C6, $0C6318C6, $0303F186, $0CE0300C, $0300C1FE, $0CC330CC, $0300C030
                long    $06619866, $0300C030, $0C6318C6, $06619866, $0CC330CC, $0C6318E6, $00000000, $00000000
                long    $0C631806, $00601806, $0C0300C0, $1B23980C, $0D2398CC, $0781E078, $0003606C, $0000D86C
                long    $11011110, $1542A954, $17677176, $0300C030, $0300C030, $0300C030, $0D8360D8, $0D8360D8
                long    $0300C030, $0D8360D8, $0D8360D8, $0D8360D8, $00000000, $00000000, $00000000, $0300C030
                long    $00000000, $00000000, $0300C030, $0300C030, $00000000, $0300C030, $0300C030, $0D8360D8
                long    $00000000, $0D8360D8, $00000000, $0D8360D8, $0D8360D8, $00000000, $0D8360D8, $00000000
                long    $00000000, $0300C030, $0D8360D8, $00000000, $00000000, $0300C030, $0D8360D8, $0D8360D8
                long    $0300C030, $00000000, $0300C030, $3FEFFBFF, $3FEFFBFF, $01E0781E, $3E0F83E1, $00000000
                long    $0760D836, $0C6318C6, $00601806, $06C1B06C, $0C603018, $0360D836, $00C1F0CC, $0300C030
                long    $0301E0CC, $06C318C6, $06C1B06C, $0CC330CC, $0003F1B6, $00C3F19E, $0180300C, $0C6318C6
                long    $0FE00000, $00000030, $00006030, $00018030, $0300C030, $0360D836, $0300C000, $0001D8DC
                long    $00000000, $00000030, $00000030, $0781B06C, $00000000, $00000000, $07C1F07C, $00000000

                byte    $00, $7E, $7E, $08, $00, $3C, $3C, $00, $FF, $00, $FF, $1E, $18, $07, $67, $18
                byte    $01, $40, $00, $66, $D8, $63, $7F, $7E, $18, $18, $00, $00, $00, $00, $00, $00
                byte    $00, $18, $00, $36, $3E, $61, $6E, $00, $30, $0C, $00, $00, $18, $00, $18, $01
                byte    $3C, $7E, $7F, $3E, $78, $3E, $3E, $0C, $3E, $1E, $00, $0C, $60, $00, $06, $18
                byte    $3E, $63, $3F, $3C, $1F, $7F, $0F, $5C, $63, $3C, $1E, $67, $7F, $C3, $63, $3E
                byte    $0F, $3E, $67, $3E, $3C, $3E, $18, $66, $C3, $3C, $FF, $3C, $40, $3C, $00, $00
                byte    $00, $6E, $3E, $3E, $6E, $3E, $0F, $3E, $67, $3C, $60, $67, $3C, $DB, $66, $3E
                byte    $3E, $3E, $0F, $3E, $38, $6E, $18, $66, $C3, $7E, $7F, $70, $18, $0E, $00, $00
                byte    $30, $6E, $3E, $6E, $6E, $6E, $6E, $60, $3E, $3E, $3E, $3C, $3C, $3C, $63, $63
                byte    $7F, $EE, $73, $3E, $3E, $3E, $6E, $6E, $7E, $3E, $3E, $18, $3F, $18, $CF, $18
                byte    $6E, $3C, $3E, $6E, $66, $63, $00, $00, $3E, $00, $00, $60, $7C, $18, $00, $00
                byte    $22, $55, $EE, $18, $18, $18, $6C, $6C, $18, $6C, $6C, $6C, $00, $00, $00, $18
                byte    $00, $00, $18, $18, $00, $18, $18, $6C, $00, $6C, $00, $6C, $6C, $00, $6C, $00
                byte    $00, $18, $6C, $00, $00, $18, $6C, $6C, $18, $00, $18, $FF, $FF, $0F, $F0, $00
                byte    $6E, $33, $03, $36, $7F, $0E, $06, $18, $7E, $1C, $77, $3C, $00, $03, $38, $63
                byte    $00, $FF, $7E, $7E, $18, $0E, $00, $00, $00, $00, $00, $38, $00, $00, $00, $00

                long    $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000
                long    $1FE7F9FE, $00000000, $1FE7F9FE, $00000000, $00000000, $00000000, $00000006, $00000000
                long    $00000000, $00000000, $00000000, $00000000, $00000000, $0000007C, $00000000, $00000000
                long    $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000
                long    $00000000, $00000000, $00000000, $00000000, $0000C030, $00000000, $00000000, $00000000
                long    $00000000, $00000000, $00000000, $00000000, $00000018, $00000000, $00000000, $00000000
                long    $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000
                long    $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000
                long    $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000
                long    $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000
                long    $00000000, $00038060, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000
                long    $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $0007F800
                long    $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $03C19860
                long    $00000000, $00000000, $078330CC, $00000000, $00000000, $00000000, $00000000, $00000000
                long    $01E0300C, $0F018060, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000
                long    $00000000, $03E180C0, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000
                long    $0001F0C0, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000078
                long    $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000
                long    $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000
                long    $03C180C0, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00007036
                long    $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000
                long    $00000000, $00000000, $00000000, $0007C060, $000300C0, $00000000, $00000000, $00000000
                long    $11011110, $1542A954, $17677176, $0300C030, $0300C030, $0300C030, $0D8360D8, $0D8360D8
                long    $0300C030, $0D8360D8, $0D8360D8, $0D8360D8, $00000000, $00000000, $00000000, $0300C030
                long    $00000000, $00000000, $0300C030, $0300C030, $00000000, $0300C030, $0300C030, $0D8360D8
                long    $00000000, $0D8360D8, $00000000, $0D8360D8, $0D8360D8, $00000000, $0D8360D8, $00000000
                long    $00000000, $0300C030, $0D8360D8, $00000000, $00000000, $0300C030, $0D8360D8, $0D8360D8
                long    $0300C030, $00000000, $0300C030, $3FEFFBFF, $3FEFFBFF, $01E0781E, $3E0F83E1, $00000000
                long    $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000006, $00000000
                long    $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000
                long    $00000000, $00000000, $00000000, $00000000, $0300C030, $00000000, $00000000, $00000000
                long    $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000, $00000000

                byte    $00, $00, $00, $00, $00, $00, $00, $00, $FF, $00, $FF, $00, $00, $00, $00, $00
                byte    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                byte    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                byte    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                byte    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                byte    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                byte    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                byte    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                byte    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                byte    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                byte    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                byte    $22, $55, $EE, $18, $18, $18, $6C, $6C, $18, $6C, $6C, $6C, $00, $00, $00, $18
                byte    $00, $00, $18, $18, $00, $18, $18, $6C, $00, $6C, $00, $6C, $6C, $00, $6C, $00
                byte    $00, $18, $6C, $00, $00, $18, $6C, $6C, $18, $00, $18, $FF, $FF, $0F, $F0, $00
                byte    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                byte    $00, $00, $00, $00, $18, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00

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

  long[mailbox][1] |= @palette << 16
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
        if_nz   wrlong  zero, scrn_             ' acknowledge screen buffer setup
        if_nz   mov     scrn, temp
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

  txt_columns = 80                              ' |
  txt_rows    = 25                              ' |
  res_x   = 720                                 ' |
  res_y   = 400                                 ' |
  res_m   = 4                                   ' UI support

  alias   = 0

DAT

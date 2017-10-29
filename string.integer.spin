' Original authors: Chip Gracey, Jon Williams
{{
    Provides simple numeric conversion methods; all methods return a pointer to
    a string.
}}
CON

    MAX_LEN = 64                                          ' 63 chars + zero terminator

VAR

    long  idx                                             ' pointer into string
    byte  nstr[MAX_LEN]                                   ' string for numeric data

PUB Dec(value)
{{
    Returns pointer to signed-decimal string
}}

    ClearStr(@nstr, MAX_LEN)                                ' clear output string
    return DecToStr(value)                                  ' return pointer to numeric string

PUB DecPadded(value, width) | t_val, field
{{
    Returns pointer to signed-decimal, fixed-width (space padded) string
}}

    ClearStr(@nstr, MAX_LEN)
    width := 1 #> width <# constant(MAX_LEN - 1)          ' qualify field width

    t_val := ||value                                      ' work with absolute
    field~                                                ' clear field

    repeat while t_val > 0                                ' count number of digits
        field++
        t_val /= 10

    field #>= 1                                           ' min field width is 1
    if value < 0                                          ' if value is negative
        field++                                             '   bump field for neg sign indicator

    if field < width                                      ' need padding?
        repeat (width - field)                              ' yes
            nstr[idx++] := " "                                '   pad with space(s)

    return DecToStr(value)

PUB DecZeroed(value, digits) | div
{{
    Returns pointer to zero-padded, signed-decimal string

    -- if value is negative, field width is digits+1
}}

    ClearStr(@nstr, MAX_LEN)
    digits := 1 #> digits <# 10

    if (value < 0)                                        ' negative value?
        -value                                              '   yes, make positive
        nstr[idx++] := "-"                                  '   and print sign indicator

    div := 1_000_000_000                                  ' initialize divisor
    if digits < 10                                        ' less than 10 digits?
        repeat (10 - digits)                                '   yes, adjust divisor
            div /= 10

    value //= (div * 10)                                  ' truncate unused digits

    repeat digits
        nstr[idx++] := (value / div + "0")                  ' convert digit to ASCII
        value //= div                                       ' update value
        div /= 10                                           ' update divisor

    return @nstr

PUB Hex(value, digits)
{{
    Returns pointer to a digits-wide hexadecimal string
}}

    ClearStr(@nstr, MAX_LEN)
    return HexToStr(value, digits)

PUB HexIndicated(value, digits)
{{
    Returns pointer to a digits-wide, indicated (with $) hexadecimal string
}}

    ClearStr(@nstr, MAX_LEN)
    nstr[idx++] := "$"
    return HexToStr(value, digits)

PUB Bin(value, digits)
{{
    Returns pointer to a digits-wide binary string
}}

    ClearStr(@nstr, MAX_LEN)
    return BinToStr(value, digits)

PUB BinIndicated(value, digits)
{{
    Returns pointer to a digits-wide, indicated (with %) binary string
}}

    ClearStr(@nstr, MAX_LEN)
    nstr[idx++] := "%"                                    ' preface with binary indicator
    return BinToStr(value, digits)

PRI ClearStr(strAddr, size)
{{
    Clears string at strAddr

    -- also resets global character pointer (idx)
}}

    bytefill(strAddr, 0, size)                            ' clear string to zeros
    idx~                                                  ' reset index

PRI DecToStr(value) | div, z_pad
{{
    Converts value to signed-decimal string equivalent
    -- characters written to current position of idx
    -- returns pointer to nstr
}}

    if (value < 0)                                        ' negative value?
        -value                                              '   yes, make positive
        nstr[idx++] := "-"                                  '   and print sign indicator

    div := 1_000_000_000                                  ' initialize divisor
    z_pad~                                                ' clear zero-pad flag

    repeat 10
        if (value => div)                                   ' printable character?
            nstr[idx++] := (value / div + "0")                '   yes, print ASCII digit
            value //= div                                     '   update value
            z_pad~~                                           '   set zflag
        elseif z_pad or (div == 1)                          ' printing or last column?
            nstr[idx++] := "0"
        div /= 10

    return @nstr

PRI HexToStr(value, digits)
{{
    Converts value to digits-wide hexadecimal string equivalent
    -- characters written to current position of idx
    -- returns pointer to nstr
}}

    digits := 1 #> digits <# 8                            ' qualify digits
    value <<= (8 - digits) << 2                           ' prep most significant digit
    repeat digits
        nstr[idx++] := lookupz((value <-= 4) & $F : "0".."9", "A".."F")

    return @nstr

PRI BinToStr(value, digits)
{{
    Converts value to digits-wide binary string equivalent
    -- characters written to current position of idx
    -- returns pointer to nstr
}}

    digits := 1 #> digits <# 32                           ' qualify digits
    value <<= 32 - digits                                 ' prep MSB
    repeat digits
        nstr[idx++] := (value <-= 1) & 1 + "0"              ' move digits (ASCII) to string

    return @nstr

PUB StrToBase(stringptr, base) : value | chr, index
{{
    Converts a zero terminated string representation of a number to a value in the designated base.

    Ignores all non-digit characters (except negative (-) when base is decimal (10)).
}}

    value := index := 0
    repeat until ((chr := byte[stringptr][index++]) == 0)
        chr := -15 + --chr & %11011111 + 39*(chr > 56)                      ' Make "0"-"9","A"-"F","a"-"f" be 0 - 15, others out of range
        if (chr > -1) and (chr < base)                                      ' Accumulate valid values into result; ignore others
            value := value * base + chr
    if (base == 10) and (byte[stringptr] == "-")                            ' If decimal, address negative sign; ignore otherwise
        value := - value


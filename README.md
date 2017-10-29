## Propeller ANSI / VT-100 Terminal

This is a serial terminal add-on board designed for the RC2014 Z80 computer. It adds VGA video output as
80x25 text (720x400@70Hz) with ANSI / VT-100 terminal emulation, and USB keyboard input. Using a single
Parallax Propeller microcontroller running at 80MHz.

![The board](board.jpg)

### Terminal ANSI Codes

The following escape sequences can be used to control the terminal behaviour

 * **`\ESC[{COUNT}A`**  
       Moves the cursor up by COUNT rows; the default count is 1.
 * **`\ESC[{COUNT}A`**  
       Moves the cursor up by COUNT rows; the default count is 1.
 * **`\ESC[{COUNT}B`**  
       Moves the cursor down by COUNT rows; the default count is 1.
 * **`\ESC[{COUNT}C`**  
       Moves the cursor forward by COUNT columns; the default count is 1.
 * **`\ESC[{COUNT}D`**  
       Moves the cursor backwards by COUNT columns; the default count is 1.
 * **`\ESC[{COUNT}2J`**  
       Erases the screen with the background colour.  
 * **`\ESC[{COUNT}K`**  
       Erases from the current cursor position to the end of the current line.  
 * **`\ESC[{COUNT}1K`**  
       Erases from the current cursor position to the start of the current line.  
 * **`\ESC[{ROW];{COLUMN}H`**  
       Sets the cursor position where subsequent text will begin. If no ROW/COLUMN parameters 
       are provided (ie. `\ESC[H`), the cursor will move to the home position, at the upper left 
       of the screen.  
 * **`\ESC[{ROW];{COLUMN}f`**  
       Same as `\ESC[{ROW];{COLUMN}H`.
 * **`\ESC[{NUM1};...;{NUMn}m`**  
       Sets multiple display attribute settings. The following lists supported attributes:  
        * **`0`** - Reset all attributes  
        * **`1`** - Bright  
        * **`2`** - Dim  
        * **`5`** - Blink  
        * **`25`** - Blink off  
        * **`30 to 37`** - Foreground color (black, red, green, yellow, blue, magenta, cyan, white)  
        * **`38;5;{NUM}`** - Foreground color to {NUM} (0-15)  
        * **`39;{NUM}`** - Default foreground color  
        * **`40 to 47`** - Background color (black, red, green, yellow, blue, magenta, cyan, white)  
        * **`48;5;{NUM}`** - Background color to {NUM} (0-7)  
        * **`49;{NUM}`** - Default background color  
 * **`\ESC[6n`**  
       Reports the cursor position to the application as (as though typed at the 
       keyboard) `\ESC[{ROW];{COLUMN}R`  
 * **`\ESC[s`**  
       Save current cursor position.
 * **`\ESC[u`**  
       Restores the saved cursor position.

Where `\ESC` is the binary character `1Bh (or 27)` and `{NUM}`, `{COUNT}`,
`{ROW}`, `{COLUMN}` is any sequence of numeric characters like `123`.

### Usage from BASIC

```
10 PRINT CHR$(27);"[1;31m";"TEXT IN RED";CHR$(27);"[39m"
```


# pico-ulisp-bc

A lightweight, infix-notation calculator DSL (Domain Specific Language) for [uLisp](http://www.ulisp.com/), inspired by the UNIX `bc` command.
This project is primarily created for the [ClockworkPi Picocalc](https://www.clockworkpi.com/picocalc).

## Features
- A custom REPL for evaluating math expressions using familiar infix notation (e.g., `1 + 2 * 3`).
- Supports C/bc-style statements and control flow: multiple statements separated by semicolons (`;`), block statements (`{ ... }`), conditionals (`if`), and loops (`while`).
- Direct access to uLisp's built-in math functions (`sin`, `cos`, `sqrt`, etc.).
- Includes built-in math and physical constants (`pi`, `e`, `phi`, `c`, `g`, `h`, `obase`).
- Supports C-style logical operators (`&&`, `||`) with short-circuit evaluation.
- Supports exponentiation (`**`), compound assignments (`+=`, `-=`, `*=`, `/=`, `%=`, `^=`, `**=`, `&=`, `|=`, `<<=`, `>>=`), and increment/decrement operators (`++`, `--`).
- Supports output base switching (`obase` = 16, 8, 2, or 10) and C-style radix inputs (`0xff`, `077`, `0b11`) for hexadecimal, octal, binary, and decimal operations.
- Supports C-style bitwise operators (`&`, `|`, `^`, `~`, `<<`, `>>`).
- Operators and variables can be typed without spaces (e.g., `1+2*3`); the REPL automatically handles padding.
- Includes `send_ulisp.py`, a handy Python utility to send `.lisp` files directly to your microcontroller via a serial port.
- Includes `test_bc.py`, an automated test suite to verify the calculator's logic over a serial connection.

## Differences from standard `bc`
While this tool mimics the feel of `bc`, it is essentially a syntactic wrapper running inside uLisp. Please note the following differences:
- **Precision**: Does not support arbitrary-precision arithmetic. It relies entirely on uLisp's native number types (standard integers/floats).
- **No Custom Functions**: Currently does not support defining user functions (`define f(x) { ... }`).

## Requirements
- A microcontroller running uLisp.
- Python 3.x and `pyserial` (for the upload script).
  ```bash
  pip install pyserial
  ```

## Usage

### 1. Uploading to the Device
Use the `send_ulisp.py` script to upload the Lisp code to your host device (replace `/dev/ttyACM0` with your actual serial port).

```bash
python send_ulisp.py bc.lisp /dev/ttyACM0
```
*Note: The default baud rate is 9600. You can change it using `--baud <rate>` if needed.*

### 2. Running the Calculator
Once the code is loaded into uLisp, invoke the `(bc)` function to start the REPL:

```lisp
> (bc)
bc> help
=== bc-calc mini manual ===
Commands:
  help : Show this message
  quit : Exit REPL

Available Functions:
  (sin cos tan asin acos atan exp log expt sqrt abs round max min)

Built-in Constants:
  pi e phi c g h obase

Syntax Examples:
  Math   : 1 + 2 * 3 ** 4
  Bitwise: ~1 & 2 | 3 ^ 4 << 5 >> 6
  Funcs  : sqrt (16 + 9)
  Assign : a = 10 % 3; a += 5
  Inc/Dec: ++a; b--
  Ans    : ans * 2 ;; Uses previous result
  Block  : { x = 1; y = 2 }
  If     : if (x == 1) { print 9 } else { print 0 }
  While  : while (x < 5) { print x; x = x + 1 }
  Base   : obase = 16 ;; Set output base to 16, 8, 2, or 10
  Radix  : 0xff + 077 + 0b11 ;; C-style hex, octal, binary input

Note: You don't need spaces around operators (e.g. 'a<5' works)
===========================
bc> 10 + 20
30
bc> ans * 2
60
bc> if (1 < 2) { print 100 }
100
bc> x = 10; y = 20; x + y
30
bc> obase = 16
#x10
bc> 255
#xFF
bc> obase = 10
10
bc> 0xff + 077 + 0b11
321
bc> 1 == 1 && 2 == 2
t
bc> ~1 & 2 | 3 ^ 4 << 5 >> 6
3
bc> quit
Bye!
```
### 3. Persisting the Functions
To keep the bc program in your microcontroller's memory across reboots, you can save the uLisp workspace to non-volatile memory (EEPROM/Flash, or the SD card). 
After uploading the code, simply run:

```lisp
> (save-image)
```

Next time you restart the device, uLisp will automatically load the saved image, and you can invoke `(bc)` right away. (Note: You can use `(load-image)` manually if your board doesn't autoload it).

### 4. Running the Tests
An automated test suite (`test_bc.py`) is provided to verify the functionality and edge cases of `bc.lisp`. After uploading the code to your device, you can run the tests over the serial port:

```bash
python test_bc.py /dev/ttyACM0
```
*Note: The script automatically handles entering and exiting the `(bc)` REPL, and will attempt to recover if an error causes the REPL to crash.*

## Note
Project code and documentation generated and assisted by Gemini.
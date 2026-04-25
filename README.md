# pico-ulisp-bc

A lightweight, infix-notation calculator DSL (Domain Specific Language) for [uLisp](http://www.ulisp.com/), inspired by the UNIX `bc` command.
This project is primarily created for the [ClockworkPi Picocalc](https://www.clockworkpi.com/picocalc).

## Features
- A custom REPL for evaluating math expressions using familiar infix notation (e.g., `(1 + 2 * 3)`).
- Supports C/bc-style control flow: block statements (`{ ... }`), conditionals (`if`), and loops (`while`).
- Direct access to uLisp's built-in math functions (`sin`, `cos`, `sqrt`, etc.).
- Includes `send_ulisp.py`, a handy Python utility to send `.lisp` files directly to your microcontroller via a serial port.

## Differences from standard `bc`
While this tool mimics the feel of `bc`, it is essentially a syntactic wrapper running inside uLisp. Please note the following differences:
- **Precision**: Does not support arbitrary-precision arithmetic. It relies entirely on uLisp's native number types (standard integers/floats).
- **Parentheses Required**: Because it relies on the Lisp `read` function, all top-level statements must be enclosed in parentheses. (e.g., `(a = 10)` instead of just `a = 10`).
- **Strict Spacing**: Operators must be separated by spaces. `(1 + 2)` is valid, but `(1+2)` will be parsed as a single Lisp symbol and cause an error.
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

Syntax Examples:
  Math   : (1 + 2 * 3)
  Funcs  : (sqrt (16 + 9))
  Assign : (a = 10 % 3)
  Block  : ( { (x = 1) (y = 2) } )
  If     : (if (x == 1) (print 9) (print 0))
  While  : (while (x < 5) ( { (print x) (x = x + 1) } ))

Note: ALWAYS use spaces around operators! (e.g. 'a < 5')
===========================
bc> (if (1 < 2) (print 100))
100
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

## Note
Project code and documentation generated and assisted by Gemini.
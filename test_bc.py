"""
A utility script to automatically test bc.lisp functionality over a serial connection.
It connects to the uLisp REPL, starts the (bc) environment, and verifies the calculator's logic.
"""

import serial
import time
import argparse
import sys
import re

# Test pattern definitions: (input expression, expected output string)
TEST_PATTERNS = [
    # 1. Atoms (literals) and basic operations
    ("42", "42"),
    ("1 + 2", "3"),
    ("10 - 3", "7"),
    ("4 * 5", "20"),
    ("10 / 2", "5"),
    ("10 % 3", "1"),
    
    # 2. Operator precedence (*, /, % have higher priority than +, -)
    ("1 + 2 * 3", "7"),
    ("10 - 2 * 3 + 1", "5"),
    
    # 3. Variable assignment and reference
    ("a = 10", "10"),
    ("a + 5", "15"),
    ("undefined_var", "0"), # Undefined variables output a warning and evaluate to 0
    
    # 4. Comparison operators
    ("5 == 5", "t"),
    ("5 != 4", "t"),
    ("3 < 4", "t"),
    ("4 > 3", "t"),
    ("3 <= 3", "t"),
    ("5 >= 6", "nil"),
    
    # 5. Math functions (calling Lisp side functions)
    ("max 10 20", "20"),
    ("min 10 20", "10"),
    ("abs (0 - 5)", "5"),
    
    # 6. Control flow: Block { ... }
    ("{ (x = 1) (y = 2) (x + y) }", "3"),
    
    # 7. Control flow: If
    ("if (1 < 2) 100 else 200", "100"),
    ("if (2 < 1) 100 else 200", "200"),
    
    # 8. Control flow: While
    ("{ (i = 0) (while (i < 3) (i = i + 1)) i }", "3"),
    
    # 8b. Control flow with Semicolon
    ("{ i = 0; while (i < 3) { i = i + 1 }; i }", "3"),

    # 8c. Multiple statements separated by semicolon
    ("print 9; print 0", "0"),

    # 8d. Semicolon edge cases (trailing, consecutive)
    ("100;", "100"),
    ("10;;20", "20"),
    
    # 8e. Nested blocks
    ("{ a = 1; { b = 2; c = 3 }; a + b + c }", "6"),

    # 8f. If with block branches
    ("if (1 < 2) { 10; 20 } else { 30; 40 }", "20"),
    ("if (2 < 1) { 10; 20 } else { 30; 40 }", "40"),

    # 8g. Complex combination (while + if + blocks)
    ("{ x = 0; y = 0; while (x < 3) { x = x + 1; if (x == 2) { y = y + 10 } else { y = y + 1 } }; y }", "12"),

    # 9. Parentheses unwrapping
    ("((100))", "100"),

    # 10. Edge case: Division by zero
    ("10 / 0", "Error: '/' division by zero"), 
    ("10 % 0", "division by zero"),

    # 11. Edge case: Arithmetic with undefined variable (treated as 0)
    ("unknown_var_b + 5", "5"),

    # 12. Edge case: Parsing with excessive whitespace
    ("   10    *    2   ", "20"),

    # 13. Edge case: Condition boundary values
    ("if 0 100 else 200", "100"), # 0 is treated as true (t) in Lisp
    ("if (2 < 1) 100", "nil"), # When there is no else clause

    # 14. Edge case: while loop that never executes
    ("{ (x = 10) (while (x < 0) (x = x + 1)) x }", "10"),

    # 15. Edge case: Empty block (adjust expected value according to implementation)
    ("{ }", "nil"),

    # 16. Ans feature: Uses previous result
    ("10 + 20", "30"),
    ("ans * 2", "60"),

    # 17. No spaces around operators (New feature)
    ("1+2", "3"),
    ("1+2*3", "7"),
    ("10-3", "7"),
    ("10/2", "5"),
    ("10%3", "1"),
    ("b=10", "10"),
    ("b+5", "15"),
    ("5==5", "t"),
    ("3<4", "t"),
    ("if(1<2)100", "100"),
    ("{(x=1)(y=2)(x+y)}", "3"),
    ("-5+3", "-2"),
    ("10*-5", "-50"),

    # 18. Output base (obase) switching
    ("obase = 16", "#x10"),
    ("255", "#xFF"),
    ("obase = 8", "#o10"),
    ("255", "#o377"),
    ("obase = 2", "#b10"),
    ("255", "#b11111111"),
    ("-5", "-#b101"),
    ("obase = 10", "10"),
    ("255", "255"),

    # 19. C-style radix inputs (Hex, Octal, Binary)
    ("0xff", "255"),
    ("0xFF", "255"),
    ("077", "63"),
    ("0b11", "3"),
    ("0B101", "5"),
    ("0xff + 077 + 0b11", "321"),
    ("0x10 * 2", "32"),

    # 20. Bitwise operations
    ("1 | 2", "3"),
    ("3 & 5", "1"),
    ("3 ^ 5", "6"),
    ("~1", "-2"),
    ("1 << 2", "4"),
    ("8 >> 2", "2"),
    
    # 21. Bitwise operator precedence
    ("1 | 2 & 3", "3"),
    ("1 << 2 + 3", "32"),
    ("10 & 15 ^ 3", "9"),
    ("~1 & 2 | 3 ^ 4 << 5 >> 6", "3"),
    ("~1&2|3^4<<5>>6", "3"),
    
    # 22. Exponentiation
    ("2 ** 3", "8"),
    ("10 ** 0", "1"),
    ("3 ** 2 * 2", "18"),
    
    # 23. Assignment Operators
    ("{ a = 10; a += 5; a }", "15"),
    ("{ a = 10; a -= 4; a }", "6"),
    ("{ a = 10; a *= 3; a }", "30"),
    ("{ a = 10; a /= 2; a }", "5"),
    ("{ a = 10; a %= 3; a }", "1"),
    ("{ a = 2; a **= 3; a }", "8"),
    ("{ a = 10; a ^= 3; a }", "9"),
    ("{ a = 3; a &= 1; a }", "1"),
    ("{ a = 3; a |= 4; a }", "7"),
    ("{ a = 1; a <<= 2; a }", "4"),
    ("{ a = 8; a >>= 2; a }", "2"),
    
    # 24. Increment and Decrement
    ("{ a = 5; ++a }", "6"),
    ("{ a = 5; a++ }", "5"),
    ("{ a = 5; a++; a }", "6"),
    ("{ a = 5; --a }", "4"),
    ("{ a = 5; a-- }", "5"),
    ("{ a = 5; a--; a }", "4"),
    ("++10", "11"),
    ("10++", "10"),
]

def read_until(ser, prompt_pattern, timeout=5.0):
    """
    Read from the serial port until the specified prompt (regex) appears.
    """
    end_time = time.time() + timeout
    buffer = ""
    while time.time() < end_time:
        if ser.in_waiting > 0:
            buffer += ser.read(ser.in_waiting).decode('utf-8', errors='ignore')
            if re.search(prompt_pattern, buffer):
                return buffer
        time.sleep(0.05)
    return buffer

def run_tests(port, baudrate):
    try:
        print(f"Connecting to {port} at {baudrate} baud...")
        with serial.Serial(port, baudrate, timeout=1) as ser:
            time.sleep(2) # Wait for the microcontroller to restart
            ser.reset_input_buffer()
            
            # Start bc
            print("Starting (bc) REPL...")
            ser.write(b'(bc)\n')
            
            init_resp = read_until(ser, r'bc>')
            if "bc>" not in init_resp:
                print("[Error] Failed to enter bc REPL. Make sure 'bc.lisp' is loaded in the device.")
                sys.exit(1)
                
            passed = 0
            failed = 0
            
            print(f"Running {len(TEST_PATTERNS)} tests...\n")
            for expr, expected in TEST_PATTERNS:
                ser.write((expr + '\n').encode('utf-8'))
                
                # Read until the next prompt (bc prompt or uLisp standard numeric prompt)
                resp = read_until(ser, r'(bc>|\n\d+>)')
                
                # Remove unnecessary prompt strings and split into lines
                clean_resp = re.sub(r'(bc>|\n\d+>)', '', resp).strip()
                lines = [line.strip() for line in clean_resp.split('\n') if line.strip()]
                
                # Check if the expected value is in the lines, considering Lisp echo back or warning messages
                if expected in lines or any(line.endswith(expected) for line in lines):
                    print(f"[PASS] {expr: <45} -> {expected}")
                    passed += 1
                else:
                    print(f"[FAIL] {expr}")
                    print(f"       Expected: {expected}")
                    print(f"       Got: {lines}")
                    failed += 1
                    
                # If the REPL crashed back to uLisp REPL due to an error, restart (bc) to recover
                if "bc>" not in resp:
                    print("       [Info] REPL crashed. Restarting (bc)...")
                    ser.write(b'(bc)\n')
                    read_until(ser, r'bc>')
                    
            # Exit bc environment with quit after tests are complete
            ser.write(b'quit\n')
            time.sleep(0.5)
            print(f"\nTest Summary: {passed} passed, {failed} failed.")
            
    except Exception as e:
        print(f"\n[Error] {e}")
        sys.exit(1)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Automated test runner for bc.lisp via Serial port.')
    parser.add_argument('port', help='Serial port name (e.g., COM3, /dev/ttyACM0)')
    parser.add_argument('--baud', type=int, default=9600, help='Baud rate (default: 9600)')
    
    args = parser.parse_args()
    run_tests(args.port, args.baud)
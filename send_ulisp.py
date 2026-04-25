"""
A utility script to send uLisp source files to a microcontroller over a serial connection.
It reads a .lisp file, strips comments and empty lines, and sends the code line by line,
allowing the uLisp REPL to process each expression.
"""

import serial
import time
import argparse
import sys

def send_lisp_file(filename, port, baudrate, delay):
    """
    Reads a Lisp file and sends it over the specified serial port.
    
    :param filename: Path to the .lisp file to be sent.
    :param port: Serial port name (e.g., COM3, /dev/ttyACM0).
    :param baudrate: Baud rate for the serial connection.
    :param delay: Delay in seconds between sending each line.
    """
    try:
        print(f"Connecting to {port} at {baudrate} baud...")
        with serial.Serial(port, baudrate, timeout=1) as ser:
            # Wait for the microcontroller to reset upon serial connection
            time.sleep(2)
            
            # Clear any stale data from the serial input buffer
            ser.reset_input_buffer()
            
            with open(filename, 'r', encoding='utf-8') as f:
                lines = f.readlines()
                
            total_lines = len(lines)
            print(f"Start sending '{filename}' ({total_lines} lines)...\n")
            
            for i, line in enumerate(lines):
                clean_line = line.strip()
                
                # Skip empty lines and single-line Lisp comments
                if not clean_line or clean_line.startswith(';'):
                    continue
                
                # Encode and send the line with a newline character
                data_to_send = (clean_line + '\n').encode('utf-8')
                ser.write(data_to_send)
                ser.flush()
                
                print(f"[{i+1:03d}/{total_lines:03d}] Sent: {clean_line}")
                
                # Wait for the microcontroller to process the line
                time.sleep(delay)
                
                # Read and print any response from the uLisp REPL (e.g., evaluation results or errors)
                while ser.in_waiting > 0:
                    response = ser.read(ser.in_waiting).decode('utf-8', errors='ignore')
                    print(response.replace('\r\n', '\n').strip('\n'))
                    
            print("\nTransfer complete!")
            
    except serial.SerialException as e:
        print(f"\n[Error] Serial port issue: {e}")
        sys.exit(1)
    except FileNotFoundError:
        print(f"\n[Error] The file '{filename}' was not found.")
        sys.exit(1)
    except Exception as e:
        print(f"\n[Error] An unexpected error occurred: {e}")
        sys.exit(1)

if __name__ == '__main__':
    # Set up command-line argument parsing
    parser = argparse.ArgumentParser(description='Send a Lisp source file to uLisp via Serial port.')
    parser.add_argument('file', help='Path to the .lisp file')
    parser.add_argument('port', help='Serial port name (e.g., COM3, /dev/ttyACM0)')
    parser.add_argument('--baud', type=int, default=9600, help='Baud rate (default: 9600)')
    parser.add_argument('--delay', type=float, default=0.1, help='Delay between lines in seconds (default: 0.1)')
    
    args = parser.parse_args()
    
    send_lisp_file(args.file, args.port, args.baud, args.delay)
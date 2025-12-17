import serial
import pyautogui

# Serial port configuration
SERIAL_PORT = 'COM6'  # Replace with your adapter's COM port
BAUD_RATE = 9600      # Baud rate for USB-to-TTL adapter

# Mouse click coordinates
CLICK_X = 500  # X-coordinate for the mouse click
CLICK_Y = 305  # Y-coordinate for the mouse click

# State tracking
zero_count = 0  # Tracks the number of "0" signals received

def main():
    global zero_count

    try:
        # Open the serial port
        ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=1)
        print(f"Listening for TTL signals on {SERIAL_PORT}...")

        while True:
            # Read raw data from the serial port
            data = ser.read(1)  # Read 1 byte
            if data:
                # Convert raw byte to integer
                signal = ord(data)  # Convert the byte to an integer (0–255)
                print(f"Received signal: {signal}")

                if signal == 0:
                    zero_count += 1  # Increfment the zero counter
                    if zero_count > 1:
                        # Second "0" triggers the mouse click
                        print("Second '0' signal received! Triggering mouse click...")
                        pyautogui.click(CLICK_X, CLICK_Y)
                        print(f"Mouse clicked at ({CLICK_X}, {CLICK_Y})")
                    #elif zero_count > 2:
                        #print(f"Ignored '0' signal. Count: {zero_count}")
    except KeyboardInterrupt:
        print("Program interrupted by user.")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        if 'ser' in locals():
            ser.close()
        print("Program terminated.")

if __name__ == "__main__":
    main()

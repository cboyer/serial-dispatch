import Config

config :serial,
    output_file: "/tmp/obd2.csv",       # Write data to file (append)
    watch_sleep: 500,                   # Monitor device availability every 500ms if disconnected
    timeout: 1000,                      # :timeout if no data is received after X ms
    listen_addr: {127,0,0,1},           # Listen for TCP connections on IP address
    listen_port: 8080,                  # Listen for TCP connections on port 8080
    speed: 115200,                      # Serial speed
    line_separator: "\n",               # End of line character
    print_data: 1,                      # Print received data in terminal
    device: %{description: "Arduino Due", manufacturer: "Arduino LLC", product_id: 62, vendor_id: 9025}                             #Macchina M2
    #device: %{product_id: 2010, vendor_id: 32903}                                                                                  #Bluetooth connection through rfcomm
    #device: %{manufacturer: "Arduino (www.arduino.cc)", product_id: 67, serial_number: "9543335363635141E0F0", vendor_id: 9025}    #Arduino Uno

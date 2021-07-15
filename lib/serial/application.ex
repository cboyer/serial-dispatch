defmodule Serial.Application do
    @moduledoc """
    Main process in charge of supervision
    """

    use Application
    use Supervisor
    require Logger


    # Configuration parameters
    @writer_output "/tmp/obd2.csv"    # Write data to file (append)
    @watch_sleep 500                  # Monitor device availability every 500ms if disconnected
    @timeout 1000                     # :timeout if no data is received after X ms
    @listen_addr {127,0,0,1}          # Listen for TCP connections on IP address
    @tcp_port 8080                    # Listen for TCP connections on port 8080
    @speed 115200                     # Serial speed
    @line_separator "\n"              # End of line character
    @print_data 1                     # Print received data in terminal

    # Device to look for
    @device %{description: "Arduino Due", manufacturer: "Arduino LLC", product_id: 62, vendor_id: 9025} #Macchina M2
    #@device %{product_id: 2010, vendor_id: 32903} #Bluetooth connection through rfcomm
    #@device %{manufacturer: "Arduino (www.arduino.cc)", product_id: 67, serial_number: "9543335363635141E0F0", vendor_id: 9025} #Arduino Uno


    # Supervisor needs a init/1 (if not defined: warning)
    def init(_arg) do
    end

    def start(_type, _args) do
        Logger.info("[#{__MODULE__}] Started at #{inspect(self())}")
        Logger.info("[#{__MODULE__}] Starting subprocesses...")

        children = [
            {Serial.Writer, [@writer_output]},
            {Serial.TcpServer, [@listen_addr, @tcp_port]},
            {Serial.Listener, [@watch_sleep, @timeout, @device, @speed, @line_separator, @print_data]}
        ]

        opts = [strategy: :one_for_one, name: Serial.Supervisor]
        {:ok, supervisor_pid} = Supervisor.start_link(children, opts)

        Logger.info("[#{__MODULE__}] All subprocesses started: #{inspect(Supervisor.which_children(supervisor_pid))}")
        {:ok, supervisor_pid}
    end
end

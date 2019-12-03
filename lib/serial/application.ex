defmodule Serial.Application do
  @moduledoc """
  Main process in charge of supervision
  """
  use Application
  use Supervisor
  require Logger

  @writer_output "/home/cyril/obd2.csv"
  @watch_sleep 500
  @tcp_port 8080
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
      {Serial.TCPwriter, [@tcp_port]},
      {Serial.Listener, [@watch_sleep, @device]}
    ]

    opts = [strategy: :one_for_one, name: Serial.Supervisor]
    {:ok, supervisor_pid} = Supervisor.start_link(children, opts)

    Logger.info(
      "[#{__MODULE__}] All subprocesses started: #{
        inspect(Supervisor.which_children(supervisor_pid))
      }"
    )

    {:ok, supervisor_pid}
  end
end

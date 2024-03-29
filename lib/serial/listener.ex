defmodule Serial.Listener do
    @moduledoc """
    Handles reading/error/disconnection for serial device
    """

    use GenServer
    require Logger


    @doc """
    Default start_link function: args come from parent (Supervisor)
    """
    def start_link(_args) do
        state = %{
            watch_sleep: Application.fetch_env!(:serial, :watch_sleep),
            timeout: Application.fetch_env!(:serial, :timeout),
            device: Application.fetch_env!(:serial, :device),
            speed: Application.fetch_env!(:serial, :speed),
            line_separator: Application.fetch_env!(:serial, :line_separator),
            print_data: Application.fetch_env!(:serial, :print_data),
            serial_pid: nil
        }

        {:ok, supervisor_pid} = GenServer.start_link(__MODULE__, state, name: __MODULE__)
        Logger.info("[#{__MODULE__}] Started at #{inspect(supervisor_pid)}")
        {:ok, supervisor_pid}
    end


    @doc """
    Default init function (executed after start_link/1)
    Parameter "state" provided with GenServer.start_link from start_link/1
    """
    def init(state) do
        with {:ok, pid} <- Circuits.UART.start_link() do
            Process.register(pid, :uart)
            state
            |> Map.put(:serial_pid, pid)
            |> start_reader()

        else
            {:error, reason} ->
                Logger.error("[#{__MODULE__}] Cannot start Circuits.UART: #{reason}")
                {:error, reason}
        end
    end


    @doc """
    Open and read correct device
    """
    def start_reader(state) do
        case Circuits.UART.enumerate() 
             |> Enum.find(fn {_device_path, device} -> device == state.device end) 
        do
            nil -> device_watch(state, true)

            {device_path, device} ->
                Logger.info("[#{__MODULE__}] Device found #{device_path} --> #{inspect(device)}")
                Circuits.UART.configure(state.serial_pid, active: true, framing: {Circuits.UART.Framing.Line, separator: state.line_separator})

                case Circuits.UART.open(state.serial_pid, device_path, speed: state.speed, active: true) do
                    :ok ->
                        Logger.info("[#{__MODULE__}] Device ready")

                    {:error, error} ->
                        Logger.warn("[#{__MODULE__}] Device opening error: #{inspect(error)}")
                        device_watch(state, true)
                end
        end

        {:ok, state, state.timeout}
    end


    @doc """
    Device watcher: started if no device connected
    """
    def device_watch(state, show_info) do
        if show_info == true, do: Logger.info("[#{__MODULE__}] Waiting for device...")
        :timer.sleep(state.watch_sleep)

        case Circuits.UART.enumerate()
             |> Enum.find(fn {_device_path, device} -> device == state.device end)
        do
            nil -> device_watch(state, false)

            {_path, _device} -> start_reader(state)
        end

        {:noreply, state}
    end


    @doc """
    Handles messages reception from Circuits.UART
    """
    def handle_info({:circuits_uart, _serial_port, message}, state) do
        case message do
            {:error, :eio} ->
                Logger.warn("[#{__MODULE__}] Device disconnected")
                device_watch(state, true)

            {:partial, data} ->
                Logger.warn("[#{__MODULE__}] Received partial: #{inspect(data)}")
                Circuits.UART.flush(state.serial_pid, :receive)

            data ->
                if state.print_data, do: IO.puts "Read: " <> inspect(data, base: :hex)
                GenServer.cast(Serial.Writer, {:write, data})
                GenServer.cast(Serial.TcpServer, {:write, data})
        end

        {:noreply, state, state.timeout}
    end

    #Handles timeout
    def handle_info(:timeout, state) do
        IO.puts "Timeout!"
        {:noreply, state, state.timeout}
    end

    #Handles messages to send through serial
    def handle_cast({:write, message}, state) do
        if state.print_data, do: IO.puts "Write: " <> inspect(message, base: :hex)
        Circuits.UART.write(state.serial_pid, message)
        {:noreply, state}
    end
end

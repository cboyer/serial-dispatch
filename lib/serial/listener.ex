defmodule Serial.Listener do
  @moduledoc """
  Handles reading/error/disconnection for serial device
  """
  use GenServer
  require Logger

  @doc """
  Default start_link function: args come from parent (Supervisor)
  """
  def start_link(args) do
    state = %{
      watch_sleep: Enum.at(args, 0),
      device: Enum.at(args, 1),
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
    # :observer.start
    # Logger.info "#{inspect Circuits.UART.enumerate}"
    {:ok, state} = start_uart(state)
    Process.register(state.serial_pid, :uart)
    start_reader(state)
  end

  @doc """
  Start Circuits.UART process
  """
  def start_uart(state) do
    if state.serial_pid != nil do
      Circuits.UART.close(state.serial_pid)
      Circuits.UART.stop(state.serial_pid)
    end

    case Circuits.UART.start_link() do
      {:ok, pid} ->
        Logger.info("[#{__MODULE__}] Circuits.UART started at: #{inspect(pid)}")
        state = Map.put(state, :serial_pid, pid)
        {:ok, state}

      {:error, reason} ->
        Logger.error("[#{__MODULE__}] Cannot start Circuits.UART: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Open and read correct device
  """
  def start_reader(state) do
    case find_device(state) do
      nil ->
        device_watch(state, true)

      {device_path, device} ->
        Logger.info("[#{__MODULE__}] Device found #{device_path} --> #{inspect(device)}")

        Circuits.UART.configure(state.serial_pid,
          framing: {Circuits.UART.Framing.Line, separator: "\r\n"}
        )

        case Circuits.UART.open(state.serial_pid, device_path, speed: 115_200, active: true) do
          :ok ->
            Logger.info("[#{__MODULE__}] Device opened, reading")

          {:error, error} ->
            Logger.warn("[#{__MODULE__}] Device opening error: #{inspect(error)}")
            device_watch(state, true)
        end
    end

    {:ok, state}
  end

  @doc """
  Find correct device specified in state.device
  """
  def find_device(state) do
    Enum.find(Circuits.UART.enumerate(), fn {_device_path, device} -> device == state.device end)
  end

  @doc """
  Device watcher: started if no device connected
  """
  def device_watch(state, show_info) do
    if show_info == true do
      Logger.info("[#{__MODULE__}] Waiting for device...")
    end

    Process.sleep(state.watch_sleep)

    case find_device(state) do
      nil ->
        device_watch(state, false)

      {_path, _device} ->
        start_reader(state)
    end

    {:noreply, state}
  end

  @doc """
  List available devices, manually executed from IEx to find device details (state.device)
  """
  def list() do
    GenServer.cast(__MODULE__, :list)
  end

  @doc """
  Cast handler: :list and :device_watch
  """
  def handle_cast(action, state) do
    case action do
      :list ->
        Logger.info("Available devices: #{inspect(Circuits.UART.enumerate())}")

      :device_watch ->
        device_watch(state, true)
    end

    {:noreply, state}
  end

  @doc """
  Circuits.UART message handler: disconnect and data
  """
  def handle_info({:circuits_uart, _serial_port, message}, state) do
    case message do
      {:error, :eio} ->
        Logger.warn("[#{__MODULE__}] Device disconnected")
        GenServer.cast(__MODULE__, :device_watch)

      data ->
        Logger.debug(data)
        Process.whereis(Serial.Writer) |> send(data)
        Process.whereis(Serial.TCPwriter) |> send(data)
    end

    {:noreply, state}
  end
end

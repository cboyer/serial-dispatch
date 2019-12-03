defmodule Serial.TCPwriter do
  @moduledoc """
  Serial.TCPwriter writes data from serial device to TCP clients
  """
  use GenServer
  require Logger

  @doc """
  Default start_link function: args come from parent (Supervisor)
  """
  def start_link(args) do
    state = %{
      port: Enum.at(args, 0),
      socket: nil
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
    {:ok, socket} = accept(state)
    state = Map.put(state, :socket, socket)
    spawn(__MODULE__, :loop_acceptor, [state])

    # Registry to keep connected clients
    {:ok, _} =
      Registry.start_link(
        keys: :duplicate,
        name: Registry.TCPclients,
        partitions: System.schedulers_online()
      )

    {:ok, state}
  end

  def accept(state) do
    {:ok, socket} =
      :gen_tcp.listen(state.port, [:binary, packet: :line, active: false, reuseaddr: true])

    Logger.info("[#{__MODULE__}] Accepting connections on port #{state.port}")
    {:ok, socket}
  end

  def loop_acceptor(state) do
    {:ok, client} = :gen_tcp.accept(state.socket)
    {:ok, _} = Registry.register(Registry.TCPclients, "Serial", client)
    Logger.info("[#{__MODULE__}] Client connected: #{inspect(client)}")
    loop_acceptor(state)
  end

  @doc """
  Message handler
  """
  def handle_info(data, state) do
    case data do
      {:partial, msg} ->
        Logger.info("[#{__MODULE__}] Received partial: #{inspect(msg)}")

      msg ->
        Registry.dispatch(Registry.TCPclients, "Serial", fn entries ->
          for {_pid, client} <- entries, do: :gen_tcp.send(client, msg)
        end)
    end

    {:noreply, state}
  end
end

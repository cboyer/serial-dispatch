defmodule Serial.TcpServer do
    @moduledoc """
    Relay data from serial device to all TCP clients and TCP client to serial
    """

    use GenServer
    require Logger


    @doc """
    Default start_link function: args come from parent (Supervisor)
    """
    def start_link(_args) do
        state = %{
            addr: Application.fetch_env!(:serial, :listen_addr),
            port: Application.fetch_env!(:serial, :listen_port),
            clients: []
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
        {:ok, listen_socket} = :gen_tcp.listen(state.port, [:binary, ip: state.addr, packet: :line, active: false, reuseaddr: true])
        spawn_link(__MODULE__, :accept_loop, [listen_socket])
        {:ok, state}
    end


    @doc """
    Accept TCP connections
    """
    def accept_loop(socket) do
        with {:ok, client_socket} <- :gen_tcp.accept(socket) do
            recv_pid = spawn(__MODULE__, :recv_loop, [client_socket])
            :gen_tcp.controlling_process(client_socket, recv_pid)
            GenServer.cast(__MODULE__, {:join, client_socket})
        end

        accept_loop(socket)
    end


    @doc """
    Handles data from clients
    """
    def recv_loop(socket) do
        case :gen_tcp.recv(socket, 0) do
            {:ok, line} ->
                #IO.inspect line, label: "Incoming packet from " <> inspect(socket)
                Process.whereis(Serial.Listener) |> send({:tcp, line})
                recv_loop(socket)

            {:error, :closed} -> GenServer.cast(__MODULE__, {:leave, socket})
            {:error, _reason} -> GenServer.cast(__MODULE__, {:leave, socket})
        end
    end


    @doc """
    Handles clients connection/disconnection
    """
    def handle_cast({:leave, client}, state) do
        IO.inspect client, label: "Client disconnected"
        {:noreply, %{state | clients: Enum.filter(state.clients, fn connected_client -> connected_client != client end)} }
    end
    def handle_cast({:join, client}, state) do
        IO.inspect client, label: "Client connected"
        {:noreply, %{state | clients: [client | state.clients]} }
    end


    @doc """
    Broadcast messages from Serial.Listener to all TCP clients
    """
    def handle_info(data, state) do
        #IO.inspect state.clients, label: "Forwarding serial message to TCP clients"
        state.clients
        |> Task.async_stream(fn client -> :gen_tcp.send(client, data) end)
        |> Enum.to_list()

        {:noreply, state}
    end
end

defmodule Serial.Writer do
    @moduledoc """
    Serial.Writer writes data from serial device to file
    """

    use GenServer
    require Logger


    @doc """
    Default start_link function: args come from parent (Supervisor)
    """
    def start_link(_args) do
        state = %{
            output_file: Application.fetch_env!(:serial, :output_file) |> File.open!([:append, :binary]),
            line_separator: Application.fetch_env!(:serial, :line_separator)
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
        {:ok, state}
    end


    @doc """
    Message handler
    """
    def handle_cast({:write, data}, state) do
        case data do
            {:partial, msg} -> Logger.info("[#{__MODULE__}] Received partial: #{inspect(msg)}")

            msg -> IO.binwrite(state.output_file, msg <> state.line_separator)
        end

        {:noreply, state}
    end
end

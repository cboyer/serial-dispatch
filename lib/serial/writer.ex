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
            output_file: Application.fetch_env!(:serial, :output_file) |> File.open!([:append, :binary])
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
    def handle_info(data, state) do
        case data do
            {:partial, msg} -> 
                Logger.info("[#{__MODULE__}] Received partial: #{inspect(msg)}")

            msg ->
                spawn(fn -> state.output_file
                            |> IO.write(msg <> "\n")
                end)
        end

        {:noreply, state}
    end
end

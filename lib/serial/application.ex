defmodule Serial.Application do
    @moduledoc """
    Main process in charge of supervision
    """

    use Application
    use Supervisor
    require Logger

    # Supervisor needs a init/1 (if not defined: warning)
    def init(_arg) do
    end

    def start(_type, _args) do
        Logger.info("[#{__MODULE__}] Started at #{inspect(self())}")
        Logger.info("[#{__MODULE__}] Starting subprocesses...")

        children = [
            {Serial.Writer, []},
            {Serial.TcpServer, []},
            {Serial.Listener, []}
        ]

        opts = [strategy: :one_for_one, name: Serial.Supervisor]
        {:ok, supervisor_pid} = Supervisor.start_link(children, opts)

        Logger.info("[#{__MODULE__}] All subprocesses started: #{inspect(Supervisor.which_children(supervisor_pid))}")
        {:ok, supervisor_pid}
    end
end

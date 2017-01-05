defmodule HanabiEngine do
  use Application
  import Supervisor.Spec

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    # Define workers and child supervisors to be supervised
    children = [
      # Starts a worker by calling: HanabiEngine.Worker.start_link(arg1, arg2, arg3)
      # worker(HanabiEngine.Worker, [arg1, arg2, arg3]),
      supervisor(Phoenix.PubSub.PG2, [:hanabi, [ ]]),
      worker(HanabiEngine.MatchMaker, [ ]),
      game_supervisor
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: HanabiEngine.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp game_supervisor do
    children = [
      worker(HanabiEngine.GameManager, [ ], restart: :transient)
    ]

    opts = [strategy: :simple_one_for_one, name: HanabiEngine.GameSupervisor]
    supervisor(Supervisor, [children, opts])
  end
end

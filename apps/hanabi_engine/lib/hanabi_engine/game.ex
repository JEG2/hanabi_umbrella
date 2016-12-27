defmodule HanabiEngine.Game do
  use GenServer

  alias HanabiEngine.GameSupervisor

  ### Client ###

  @doc ~S"""
  This is the main start interface for client code.

  All `Game` processes are dynamically started under a `GameSupervisor`.
  This function handles that sequence for the caller.

  `players` is expected to be a `List` of unique identifiers representing
  the players in this game.
  """
  def start(players) do
    Supervisor.start_child(GameSupervisor, [players])
  end

  # used by GameSupervisor and test code
  @doc false
  def start_link(players, options \\ [ ]) do
    GenServer.start_link(__MODULE__, players, options)
  end
end

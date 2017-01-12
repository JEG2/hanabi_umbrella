defmodule HanabiStorage.Recorder do
  use GenServer

  alias HanabiStorage.{Game, Repo}

  ### Client ###

  def start_link do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def start_game(id, players, seed) do
    GenServer.call(__MODULE__, {:start_game, id, players, seed})
  end

  ### Server ###

  def handle_call({:start_game, id, players, seed}, _from, nil) do
    Game.start_changeset(id, players, seed)
    |> Repo.insert!
    {:reply, :ok, nil}
  end
end

defmodule HanabiStorage.Recorder do
  use GenServer
  require Logger

  alias HanabiStorage.{Game, Move, Repo}

  ### Client ###

  def start_link do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def start_game(id, players, seed) do
    GenServer.call(__MODULE__, {:start_game, id, players, seed})
  end

  def record_game(id) do
    GenServer.call(__MODULE__, {:record_game, id})
  end

  ### Server ###

  def handle_call({:start_game, id, players, seed}, _from, nil) do
    HanabiEngine.GameManager.subscribe(id)
    Game.started_changeset(id, players, seed)
    |> Repo.insert!
    {:reply, :ok, nil}
  end

  def handle_call({:record_game, id}, _from, nil) do
    HanabiEngine.GameManager.subscribe(id)
    {:reply, :ok, nil}
  end

  def handle_info({{:hint, player, to, hint}, :ok, game_id, _game}, nil) do
    Move.changeset(game_id, "hint", [player, to, hint])
    |> Repo.insert!
    {:noreply, nil}
  end
  def handle_info({{:discard, player, index}, :ok, game_id, _game}, nil) do
    Move.changeset(game_id, "discard", [player, index])
    |> Repo.insert!
    {:noreply, nil}
  end
  def handle_info({{:play, player, index}, :ok, game_id, _game}, nil) do
    Move.changeset(game_id, "play", [player, index])
    |> Repo.insert!
    {:noreply, nil}
  end
  def handle_info(message, nil) do
    Logger.debug "Unsaved message:  #{inspect message}"
    {:noreply, nil}
  end
end

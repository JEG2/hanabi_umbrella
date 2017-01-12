defmodule HanabiEngine.GameManager do
  @moduledoc ~S"""
  This process keeps track of a `Game` in progress.  The process will
  subscribe to incoming moves and publish updates for each event.
  """

  use GenServer

  defstruct ~w[id game]a

  alias Phoenix.PubSub
  alias HanabiEngine.{Game, GameSupervisor, RulesLawyer}

  ### Client ###

  @doc ~S"""
  Creates the `game_id` and `seed` expected by `start/3`, then forwards to that
  function.  Returns `{:ok, game_id, players, seed}` or `{:error, message}`.
  """
  def start_new(players) do
    game_id = UUID.uuid1
    seed = :rand.seed_s(:exsplus) |> :rand.export_seed_s
    result = start(game_id, players, seed)
    case result do
      success when is_tuple(success) and elem(success, 0) == :ok ->
        {:ok, game_id, players, seed}
      error ->
        error
    end
  end

  @doc ~S"""
  All `GameManager` processes are dynamically started under a `GameSupervisor`.
  This function handles that sequence for the caller.

  A `game_id` is a unique `String` identifier for the game being built.
  Events for the game will be published to a topic beginning
  `"game:#{game_id}:events"`.  The `GameManager` subscribes to the topic
  `"game:#{game_id}:plays"` where it will pick up moves from the players.

  `players` is expected to be a `List` of unique identifiers representing
  the players in this game.

  You can provide a `seed` (an `export_state()` from `:rand`) to make all
  randomization the `GameManager` does predictable.  This allows for the
  recreation of games from long term storage.
  """
  def start(game_id, players, seed \\ nil) do
    Supervisor.start_child(GameSupervisor, [game_id, players, seed])
  end

  # used by GameSupervisor and test code
  @doc false
  def start_link(game_id, players, seed \\ nil, options \\ [ ]) do
    GenServer.start_link(__MODULE__, {game_id, players, seed}, options)
  end

  @doc ~S"""
  Subscribe to receive event messages from the `Game` with `id`.
  """
  def subscribe(id) do
    PubSub.subscribe(:hanabi, "game:#{id}:events")
  end

  @doc ~S"""
  Publishes a request to deal the `Game` with `id`.
  """
  def deal(id) do
    PubSub.broadcast(:hanabi, "game:#{id}:plays", :deal)
  end

  @doc ~S"""
  Publishes a hint move the `Game` with `id`.
  """
  def hint(id, player, to, hint) do
    PubSub.broadcast(:hanabi, "game:#{id}:plays", {:hint, player, to, hint})
  end

  @doc ~S"""
  Publishes a discard move the `Game` with `id`.
  """
  def discard(id, player, index) do
    PubSub.broadcast(:hanabi, "game:#{id}:plays", {:discard, player, index})
  end

  @doc ~S"""
  Publishes a play move the `Game` with `id`.
  """
  def play(id, player, index) do
    PubSub.broadcast(:hanabi, "game:#{id}:plays", {:play, player, index})
  end

  ### Server ###

  @doc false
  def init({game_id, _players, _seed}) when not is_binary(game_id),
    do: {:stop, "A game ID must be a String."}
  def init({_game_id, players, _seed})
  when not is_list(players) or not length(players) in 2..5,
    do: {:stop, "A game requires a List of 2 to 5 players."}
  def init({_game_id, _players, seed})
  when not (is_nil(seed)
  or (is_tuple(seed) and tuple_size(seed) == 2)
  and is_atom(elem(seed, 0))
  and is_list(elem(seed, 1))
  and is_integer(hd(elem(seed, 1)))
  and is_integer(tl(elem(seed, 1)))),
    do: {:stop, "A game seed is Tuple of three Integer values."}
  def init({game_id, players, seed}) do
    if seed, do: :rand.seed(seed)

    PubSub.subscribe(:hanabi, "game:#{game_id}:plays")

    {:ok, %__MODULE__{id: game_id, game: Game.new(players)}}
  end

  @doc false
  def handle_info(move = :deal, %__MODULE__{id: id, game: game}) do
    {reply, new_game} = RulesLawyer.deal_if_legal(game)
    publish(id, move, reply, new_game)
    {:noreply, %__MODULE__{id: id, game: new_game}}
  end

  @doc false
  def handle_info(
    move = {:hint, player, to, hint},
    %__MODULE__{id: id, game: game}
  ) do
    {reply, new_game} = RulesLawyer.hint_if_legal(game, player, to, hint)
    publish(id, move, reply, new_game)
    {:noreply, %__MODULE__{id: id, game: new_game}}
  end

  @doc false
  def handle_info(
    move = {:discard, player, index},
    %__MODULE__{id: id, game: game}
  ) do
    {reply, new_game} = RulesLawyer.discard_if_legal(game, player, index)
    publish(id, move, reply, new_game)
    {:noreply, %__MODULE__{id: id, game: new_game}}
  end

  @doc false
  def handle_info(
    move = {:play, player, index},
    %__MODULE__{id: id, game: game}
  ) do
    {reply, new_game} = RulesLawyer.play_if_legal(game, player, index)
    publish(id, move, reply, new_game)
    {:noreply, %__MODULE__{id: id, game: new_game}}
  end

  ### Helpers ###

  defp publish(id, move, reply, game) do
    PubSub.broadcast(:hanabi, "game:#{id}:events", {move, reply, id, game})
  end
end

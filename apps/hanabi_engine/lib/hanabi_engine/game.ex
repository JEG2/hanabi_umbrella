defmodule HanabiEngine.Game do
  use GenServer

  defstruct id: nil, status: :setup, players: nil, hands: nil, draw_pile: nil

  alias Phoenix.PubSub
  alias HanabiEngine.GameSupervisor

  ### Client ###

  @doc ~S"""
  This is the main start interface for client code.

  All `Game` processes are dynamically started under a `GameSupervisor`.
  This function handles that sequence for the caller.

  A `game_id` is a unique `String` identifier for the game being built.
  Events for the game will be published to a topic beginning
  `"game:#{game_id}"`.

  `players` is expected to be a `List` of unique identifiers representing
  the players in this game.

  You can provide a `seed` (a `Tuple` of three `Integer` values) to make
  all randomization the `Game` does predictable.  This allows for the
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
  This function triggers the initial deal of player hands and completes
  game setup.
  """
  def deal(game) do
    GenServer.call(game, :deal)
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
  or (is_tuple(seed) and tuple_size(seed) == 3
  and (is_integer(elem(seed, 0))
  and is_integer(elem(seed, 1))
  and is_integer(elem(seed, 2))))),
    do: {:stop, "A game seed is Tuple of three Integer values."}
  def init({game_id, players, seed}) do
    if seed do
      :rand.seed(:exsplus, seed)
    end

    all_tiles =
      for color <- ~w[blue green red white yellow]a,
        value <- [1, 1, 1, 2, 2, 3, 3, 4, 4, 5] do
          {color, value}
      end
    game =
      %__MODULE__{
        id: game_id,
        players: List.to_tuple(players),
        draw_pile: Enum.shuffle(all_tiles)
      }

    {:ok, game}
  end

  @doc false
  def handle_call(:deal, _from, game = %__MODULE__{status: :setup}) do
    hand_size = if tuple_size(game.players) < 4, do: 5, else: 4
    tile_count = tuple_size(game.players) * hand_size
    tiles =
      game.draw_pile
      |> Enum.take(tile_count)
      |> Enum.chunk(hand_size)
    hands =
      Enum.zip(Tuple.to_list(game.players), tiles)
      |> Enum.into(%{ })
    new_draw_pile = Enum.drop(game.draw_pile, tile_count)

    Enum.each(hands, fn {player, hand} ->
      PubSub.broadcast(:hanabi, "game:#{game.id}:#{player}", {:dealt, hand})
    end)

    {:reply, :ok, %__MODULE__{game | hands: hands, draw_pile: new_draw_pile}}
  end
  def handle_call(:deal, _from, _game) do
    {:reply, {:error, "The game is already setup."}}
  end
end

defmodule HanabiEngine.GameManager do
  use GenServer

  defstruct id: nil,
            status: :setup,
            players: nil,
            hands: nil,
            draw_pile: nil,
            discards: [ ],
            fireworks: %{
              blue: nil,
              green: nil,
              red: nil,
              white: nil,
              yellow: nil
            },
            turn: nil,
            clocks: 8,
            fuses: 3

  alias Phoenix.PubSub
  alias HanabiEngine.GameSupervisor

  ### Client ###

  @doc ~S"""
  This is the main start interface for client code.

  All `GameManager` processes are dynamically started under a `GameSupervisor`.
  This function handles that sequence for the caller.

  A `game_id` is a unique `String` identifier for the game being built.
  Events for the game will be published to a topic beginning
  `"game:#{game_id}"`.

  `players` is expected to be a `List` of unique identifiers representing
  the players in this game.

  You can provide a `seed` (a `Tuple` of three `Integer` values) to make
  all randomization the `GameManager` does predictable.  This allows for the
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
  `game` setup.

  Details of the setup will be published to each player.
  """
  def deal(game) do
    GenServer.call(game, :deal)
  end

  @doc ~S"""
  One of three play functions for the players.

  `game` is the process identifier, `player` is the player making the play
  (who must be the current player), `to` is the player receiving the hint,
  and `hint` is either a color atom (like `:yellow`) or a value (like `3`).

  Details of the play will be published to each player.
  """
  def hint(game, player, to, hint) do
    GenServer.call(game, {:hint, player, to, hint})
  end

  @doc ~S"""
  One of three play functions for the players.

  `game` is the process identifier, `player` is the player making the play
  (who must be the current player), and `index` is the zero-based index into
  the player's hand of the tile they wish to discard.  A fresh tile will be
  drawn into the player's hand at the same position, if one is available.

  Details of the play will be published to each player.
  """
  def discard(game, player, index) do
    GenServer.call(game, {:discard, player, index})
  end

  @doc ~S"""
  One of three play functions for the players.

  `game` is the process identifier, `player` is the player making the play
  (who must be the current player), and `index` is the zero-based index into
  the player's hand of the tile they wish to play.  A fresh tile will be
  drawn into the player's hand at the same position, if one is available.

  Details of the play will be published to each player.
  """
  def play(game, player, index) do
    GenServer.call(game, {:play, player, index})
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
        players: players,
        draw_pile: Enum.shuffle(all_tiles),
        turn: hd(players)
      }

    {:ok, game}
  end

  @doc false
  def handle_call(:deal, _from, game = %__MODULE__{status: :setup}) do
    player_count = length(game.players)
    hand_size = if player_count < 4, do: 5, else: 4
    tile_count = player_count * hand_size
    tiles =
      game.draw_pile
      |> Enum.take(tile_count)
      |> Enum.chunk(hand_size)
    hands =
      game.players
      |> Enum.zip(tiles)
      |> Enum.into(%{ })
    new_draw_pile = Enum.drop(game.draw_pile, tile_count)
    new_game =
      %__MODULE__{
        game |
        status: :playing,
        hands: hands,
        draw_pile: new_draw_pile
      }

    Enum.each(new_game.players, fn player ->
      details = %{
        players: new_game.players,
        hands: Map.update!(new_game.hands, player, fn hand -> length(hand) end),
        new_draw_pile: length(new_game.draw_pile),
        discards: new_game.discards,
        fireworks: new_game.fireworks,
        next_turn: new_game.turn,
        new_clocks: new_game.clocks,
        new_fuses: new_game.fuses
      }
      PubSub.broadcast(
        :hanabi,
        "game:#{new_game.id}:#{player}",
        {:deal, player, details}
      )
    end)

    {:reply, :ok, new_game}
  end
  def handle_call(:deal, _from, game),
    do: {:reply, {:error, "The game is already setup."}, game}

  @doc false
  def handle_call(
    {:hint, player, to, hint},
    _from,
    game = %__MODULE__{status: :playing, turn: player, clocks: clocks}
  ) when clocks > 0 do
    hand = Map.fetch!(game.hands, to)
    empty = map_hand(hand, 0, hint, nil, nil)
    {type, positions} =
      if is_atom(hint) do
        {:color, map_hand(hand, 0, hint, hint, nil)}
      else
        {:value, map_hand(hand, 1, hint, hint, nil)}
      end
    if Enum.any?(positions) do
      new_game = %__MODULE__{
        game |
        turn: next_turn(game),
        clocks: clocks - 1
      }

      details =
        %{
          to: to,
          color: empty,
          value: empty,
          next_turn: new_game.turn,
          new_clocks: new_game.clocks
        }
        |> Map.put(type, positions)
      Enum.each(new_game.players, fn other_player ->
        PubSub.broadcast(
          :hanabi,
          "game:#{new_game.id}:#{other_player}",
          {:hint, player, details}
        )
      end)

      {:reply, :ok, new_game}
    else
      {:reply, {:error, "Invalid hint."}, game}
    end
  end
  def handle_call({:hint, _player, _to, _hint}, _from, game),
    do: {:reply, {:error, "That player cannot give a hint right now."}, game}

  @doc false
  def handle_call(
    {:discard, player, index},
    _from,
    game = %__MODULE__{status: :playing, turn: player}
  ) do
    hand = game.hands |> Map.fetch!(player)
    discard = hand |> Enum.at(index)
    if discard do
      drawn = hd(game.draw_pile)
      new_hand = List.replace_at(hand, index, drawn)
      new_game = %__MODULE__{
        game |
        hands: Map.put(game.hands, player, new_hand),
        draw_pile: tl(game.draw_pile),
        discards: [discard | game.discards],
        turn: next_turn(game),
        clocks: Enum.min([game.clocks + 1, 8])
      }

      details =
        %{
          discarded: discard,
          drawn: drawn,
          new_draw_pile: length(new_game.draw_pile),
          next_turn: next_turn(game),
          new_clocks: new_game.clocks
        }
      Enum.each(new_game.players, fn other_player ->
        PubSub.broadcast(
          :hanabi,
          "game:#{new_game.id}:#{other_player}",
          {:discard, player, details}
        )
      end)

      {:reply, :ok, new_game}
    else
      {:reply, {:error, "Invalid discard."}, game}
    end
  end
  def handle_call({:discard, _player, _index}, _from, game),
    do: {:reply, {:error, "That player cannot discard right now."}, game}

  @doc false
  def handle_call(
    {:play, player, index},
    _from,
    game = %__MODULE__{status: :playing, turn: player}
  ) do
    hand = game.hands |> Map.fetch!(player)
    tile = hand |> Enum.at(index)
    if tile do
      drawn = hd(game.draw_pile)
      new_hand = List.replace_at(hand, index, drawn)
      color = elem(tile, 0)
      fireworks = game.fireworks
      {new_fireworks, played, discarded, new_fuses} =
        if (Map.fetch!(fireworks, color) || 0) + 1 == elem(tile, 1) do
          {
            Map.put(fireworks, elem(tile, 0), elem(tile, 1)),
            tile,
            nil,
            game.fuses
          }
        else
          {fireworks, nil, tile, game.fuses - 1}
        end
      new_discards =
        if discarded do
          [discarded | game.discards]
        else
          game.discards
        end
      new_game = %__MODULE__{
        game |
        hands: Map.put(game.hands, player, new_hand),
        draw_pile: tl(game.draw_pile),
        discards: new_discards,
        fireworks: new_fireworks,
        turn: next_turn(game),
        fuses: new_fuses
      }

      details =
        %{
          played: played,
          discarded: discarded,
          drawn: drawn,
          new_draw_pile: length(new_game.draw_pile),
          next_turn: next_turn(game),
          new_clocks: new_game.clocks,
          new_fuses: new_game.fuses
        }
      Enum.each(new_game.players, fn other_player ->
        PubSub.broadcast(
          :hanabi,
          "game:#{new_game.id}:#{other_player}",
          {:play, player, details}
        )
      end)

      {:reply, :ok, new_game}
    else
      {:reply, {:error, "Invalid play."}, game}
    end
  end
  def handle_call({:play, _player, _index}, _from, game),
    do: {:reply, {:error, "That player cannot make a play right now."}, game}

  ### Helpers ###

  defp map_hand(hand, i, test, match, non_match) do
    Enum.map(hand, fn tile ->
      if elem(tile, i) == test, do: match, else: non_match
    end)
  end

  defp next_turn(game) do
    i = Enum.find_index(game.players, fn player -> player == game.turn end)
    Enum.at(game.players, i + 1, hd(game.players))
  end
end

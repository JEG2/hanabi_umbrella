defmodule HanabiEngine.Game do
  defstruct status: :started,
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

  def new(players) do
    %__MODULE__{players: players}
  end

  @doc ~S"""
  This function triggers the initial deal of player hands and completes
  `Game` setup.
  """
  def deal(game) do
    player_count = length(game.players)
    hand_size = if player_count < 4, do: 5, else: 4
    tile_count = player_count * hand_size
    all_tiles =
      for color <- ~w[blue green red white yellow]a,
        value <- [1, 1, 1, 2, 2, 3, 3, 4, 4, 5] do
          {color, value}
      end
      |> Enum.shuffle
    tiles = all_tiles |> Enum.take(tile_count) |> Enum.chunk(hand_size)
    hands = game.players |> Enum.zip(tiles) |> Enum.into(%{ })
    draw_pile = Enum.drop(all_tiles, tile_count)
    %__MODULE__{
      game |
      status: :playing,
      hands: hands,
      draw_pile: draw_pile,
      turn: hd(game.players)
    }
  end

  # @doc ~S"""
  # One of three play functions for the players.

  # `game` is the process identifier, `player` is the player making the play
  # (who must be the current player), `to` is the player receiving the hint,
  # and `hint` is either a color atom (like `:yellow`) or a value (like `3`).

  # Details of the play will be published to each player.
  # """
  # def hint(game, player, to, hint) do
  #   GenServer.call(game, {:hint, player, to, hint})
  # end

  # @doc false
  # def handle_call(
  #   {:hint, player, to, hint},
  #   _from,
  #   game = %__MODULE__{status: :playing, turn: player, clocks: clocks}
  # ) when clocks > 0 do
  #   hand = Map.fetch!(game.hands, to)
  #   empty = map_hand(hand, 0, hint, nil, nil)
  #   {type, positions} =
  #     if is_atom(hint) do
  #       {:color, map_hand(hand, 0, hint, hint, nil)}
  #     else
  #       {:value, map_hand(hand, 1, hint, hint, nil)}
  #     end
  #   if Enum.any?(positions) do
  #     new_game = %__MODULE__{
  #       game |
  #       turn: next_turn(game),
  #       clocks: clocks - 1
  #     }

  #     details =
  #       %{
  #         to: to,
  #         color: empty,
  #         value: empty,
  #         next_turn: new_game.turn,
  #         new_clocks: new_game.clocks
  #       }
  #       |> Map.put(type, positions)
  #     Enum.each(new_game.players, fn other_player ->
  #       PubSub.broadcast(
  #         :hanabi,
  #         "game:#{new_game.id}:#{other_player}",
  #         {:hint, player, details}
  #       )
  #     end)

  #     {:reply, :ok, new_game}
  #   else
  #     {:reply, {:error, "Invalid hint."}, game}
  #   end
  # end
  # def handle_call({:hint, _player, _to, _hint}, _from, game),
  #   do: {:reply, {:error, "That player cannot give a hint right now."}, game}

  # @doc ~S"""
  # One of three play functions for the players.

  # `game` is the process identifier, `player` is the player making the play
  # (who must be the current player), and `index` is the zero-based index into
  # the player's hand of the tile they wish to discard.  A fresh tile will be
  # drawn into the player's hand at the same position, if one is available.

  # Details of the play will be published to each player.
  # """
  # def discard(game, player, index) do
  #   GenServer.call(game, {:discard, player, index})
  # end

  # @doc false
  # def handle_call(
  #   {:discard, player, index},
  #   _from,
  #   game = %__MODULE__{status: :playing, turn: player}
  # ) do
  #   hand = game.hands |> Map.fetch!(player)
  #   discard = hand |> Enum.at(index)
  #   if discard do
  #     drawn = hd(game.draw_pile)
  #     new_hand = List.replace_at(hand, index, drawn)
  #     new_game = %__MODULE__{
  #       game |
  #       hands: Map.put(game.hands, player, new_hand),
  #       draw_pile: tl(game.draw_pile),
  #       discards: [discard | game.discards],
  #       turn: next_turn(game),
  #       clocks: Enum.min([game.clocks + 1, 8])
  #     }

  #     details =
  #       %{
  #         discarded: discard,
  #         drawn: drawn,
  #         new_draw_pile: length(new_game.draw_pile),
  #         next_turn: next_turn(game),
  #         new_clocks: new_game.clocks
  #       }
  #     Enum.each(new_game.players, fn other_player ->
  #       PubSub.broadcast(
  #         :hanabi,
  #         "game:#{new_game.id}:#{other_player}",
  #         {:discard, player, details}
  #       )
  #     end)

  #     {:reply, :ok, new_game}
  #   else
  #     {:reply, {:error, "Invalid discard."}, game}
  #   end
  # end
  # def handle_call({:discard, _player, _index}, _from, game),
  #   do: {:reply, {:error, "That player cannot discard right now."}, game}

  # @doc ~S"""
  # One of three play functions for the players.

  # `game` is the process identifier, `player` is the player making the play
  # (who must be the current player), and `index` is the zero-based index into
  # the player's hand of the tile they wish to play.  A fresh tile will be
  # drawn into the player's hand at the same position, if one is available.

  # Details of the play will be published to each player.
  # """
  # def play(game, player, index) do
  #   GenServer.call(game, {:play, player, index})
  # end

  # @doc false
  # def handle_call(
  #   {:play, player, index},
  #   _from,
  #   game = %__MODULE__{status: :playing, turn: player}
  # ) do
  #   hand = game.hands |> Map.fetch!(player)
  #   tile = hand |> Enum.at(index)
  #   if tile do
  #     drawn = hd(game.draw_pile)
  #     new_hand = List.replace_at(hand, index, drawn)
  #     color = elem(tile, 0)
  #     fireworks = game.fireworks
  #     {new_fireworks, played, discarded, new_fuses} =
  #       if (Map.fetch!(fireworks, color) || 0) + 1 == elem(tile, 1) do
  #         {
  #           Map.put(fireworks, elem(tile, 0), elem(tile, 1)),
  #           tile,
  #           nil,
  #           game.fuses
  #         }
  #       else
  #         {fireworks, nil, tile, game.fuses - 1}
  #       end
  #     new_discards =
  #       if discarded do
  #         [discarded | game.discards]
  #       else
  #         game.discards
  #       end
  #     new_game = %__MODULE__{
  #       game |
  #       hands: Map.put(game.hands, player, new_hand),
  #       draw_pile: tl(game.draw_pile),
  #       discards: new_discards,
  #       fireworks: new_fireworks,
  #       turn: next_turn(game),
  #       fuses: new_fuses
  #     }

  #     details =
  #       %{
  #         played: played,
  #         discarded: discarded,
  #         drawn: drawn,
  #         new_draw_pile: length(new_game.draw_pile),
  #         next_turn: next_turn(game),
  #         new_clocks: new_game.clocks,
  #         new_fuses: new_game.fuses
  #       }
  #     Enum.each(new_game.players, fn other_player ->
  #       PubSub.broadcast(
  #         :hanabi,
  #         "game:#{new_game.id}:#{other_player}",
  #         {:play, player, details}
  #       )
  #     end)

  #     {:reply, :ok, new_game}
  #   else
  #     {:reply, {:error, "Invalid play."}, game}
  #   end
  # end
  # def handle_call({:play, _player, _index}, _from, game),
  #   do: {:reply, {:error, "That player cannot make a play right now."}, game}

  def to_table_view(game) do
    game
    |> Map.from_struct
    |> Map.delete(:status)
    |> Map.update!(:draw_pile, fn tiles -> length(tiles) end)
    |> tuples_to_lists
  end

  def to_player_view(table_view, player) do
    update_in(table_view, [:hands, player], fn hand -> length(hand) end)
    |> Map.put(:my_turn, table_view.turn == player)
  end

  ### Helpers ###

  defp tuples_to_lists(data) when is_map(data) do
    Enum.into(data, %{ }, fn {key, value} ->
      {tuples_to_lists(key), tuples_to_lists(value)}
    end)
  end
  defp tuples_to_lists(data) when is_list(data) do
    Enum.map(data, &tuples_to_lists/1)
  end
  defp tuples_to_lists(data) when is_tuple(data) do
    Tuple.to_list(data) |> tuples_to_lists
  end
  defp tuples_to_lists(data) do
    data
  end

  # defp map_hand(hand, i, test, match, non_match) do
  #   Enum.map(hand, fn tile ->
  #     if elem(tile, i) == test, do: match, else: non_match
  #   end)
  # end

  # defp next_turn(game) do
  #   i = Enum.find_index(game.players, fn player -> player == game.turn end)
  #   Enum.at(game.players, i + 1, hd(game.players))
  # end
end

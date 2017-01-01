defmodule HanabiEngine.Game do
  defstruct status: :started,
            players: nil,
            hands: nil,
            knowns: nil,
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

  @doc ~S"""
  Builds a new `Game` data structure from a `List` of player names.
  """
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
    no_knowns = List.duplicate({nil, nil}, hand_size)
    knowns =
      game.players
      |> Enum.map(fn player -> {player, no_knowns} end)
      |> Enum.into(%{ })
    draw_pile = Enum.drop(all_tiles, tile_count)
    %__MODULE__{
      game |
      status: :playing,
      hands: hands,
      knowns: knowns,
      draw_pile: draw_pile,
      turn: hd(game.players)
    }
  end

  @doc ~S"""
  One of three play functions for the players.

  `game` is a `Game` struct, `player` is the name of the player making the play
  (who must be the current player), `to` is the name of the player receiving the
  hint, and `hint` is either a color atom (like `:yellow`) or a value
  (like `3`).
  """
  def hint(game, _player, to, hint) do
    hand = Map.fetch!(game.hands, to)
    knowns = Map.fetch!(game.knowns, to)
    new_knowns =
      knowns
      |> Enum.zip(hand)
      |> Enum.map(fn {{knowns_color, knowns_value}, {hand_color, hand_value}} ->
        cond do
          hint == hand_color -> {hint, knowns_value}
          hint == hand_value -> {knowns_color, hint}
          true -> {knowns_color, knowns_value}
        end
      end)
    %__MODULE__{
      game |
      knowns: Map.put(game.knowns, to, new_knowns),
      turn: next_turn(game),
      clocks: game.clocks - 1
    }
  end

  @doc ~S"""
  One of three play functions for the players.

  `game` is a `Game` struct, `player` is the name of the player making the play
  (who must be the current player), and `index` is the zero-based index into the
  player's hand of the tile they wish to discard.  A fresh tile will be drawn
  into the player's hand at the same position, if one is available.
  """
  def discard(game, player, index) do
    hand = game.hands |> Map.fetch!(player)
    knowns = game.knowns |> Map.fetch!(player)
    discard = hand |> Enum.at(index)
    drawn = draw(game)
    new_hand = List.replace_at(hand, index, drawn)
    new_knowns = List.replace_at(knowns, index, {nil, nil})
    %__MODULE__{
      game |
      hands: Map.put(game.hands, player, new_hand),
      knowns: Map.put(game.knowns, player, new_knowns),
      draw_pile: post_draw_pile(game),
      discards: [discard | game.discards],
      turn: next_turn(game),
      clocks: Enum.min([game.clocks + 1, 8])
    }
  end

  @doc ~S"""
  One of three play functions for the players.

  `game` is a `Game` struct, `player` is the name of the player making the play
  (who must be the current player), and `index` is the zero-based index into
  the player's hand of the tile they wish to play.  A fresh tile will be
  drawn into the player's hand at the same position, if one is available.
  """
  def play(game, player, index) do
    hand = game.hands |> Map.fetch!(player)
    knowns = game.knowns |> Map.fetch!(player)
    tile = hand |> Enum.at(index)
    drawn = draw(game)
    new_hand = List.replace_at(hand, index, drawn)
    new_knowns = List.replace_at(knowns, index, {nil, nil})
    color = elem(tile, 0)
    fireworks = game.fireworks
    {new_fireworks, new_discards, new_fuses} =
      if (Map.fetch!(fireworks, color) || 0) + 1 == elem(tile, 1) do
        {
          Map.put(fireworks, color, elem(tile, 1)),
          game.discards,
          game.fuses
        }
      else
        {fireworks, [tile | game.discards], game.fuses - 1}
      end
    %__MODULE__{
      game |
      hands: Map.put(game.hands, player, new_hand),
      knowns: Map.put(game.knowns, player, new_knowns),
      draw_pile: post_draw_pile(game),
      discards: new_discards,
      fireworks: new_fireworks,
      turn: next_turn(game),
      fuses: new_fuses
    }
  end

  @doc ~S"""
  Converts the passed `game` struct to viewable information by `player`.  The
  data is also prepared for serialization.
  """
  def to_player_view(game, player) do
    game
    |> Map.from_struct
    |> Map.delete(:status)
    |> Map.update!(:draw_pile, fn tiles -> length(tiles) end)
    |> Map.update!(:hands, fn hands -> Map.delete(hands, player) end)
    |> Map.put(:my_hand, Map.fetch!(game.knowns, player))
    |> Map.delete(:knowns)
    |> Map.put(:my_turn, game.turn == player)
    |> tuples_to_lists
  end

  ### Helpers ###

  defp next_turn(game) do
    i = Enum.find_index(game.players, fn player -> player == game.turn end)
    Enum.at(game.players, i + 1, hd(game.players))
  end

  defp draw(%__MODULE__{draw_pile: [tile | _tiles]}), do: tile
  defp draw(%__MODULE__{draw_pile: [ ]}), do: {nil, nil}

  defp post_draw_pile(%__MODULE__{draw_pile: [_tile | tiles]}), do: tiles
  defp post_draw_pile(%__MODULE__{draw_pile: [ ]}), do: [ ]

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
  defp tuples_to_lists(data), do: data
end

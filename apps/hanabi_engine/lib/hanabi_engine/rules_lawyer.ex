defmodule HanabiEngine.RulesLawyer do
  @moduledoc ~S"""
  `RulesLawyer` provides a layer of validation above `Game`.  Call these
  functions to ensure that only legal plays reach the `Game` data structure.
  """

  alias HanabiEngine.Game

  @doc ~S"""
  Calls `Game.deal/0` on `game`, if it is currently legal to do so.

  Returns `{reply, game}` where `reply` is `:ok` or `{:error, message}` and
  `game` is the changed or not `Game`.
  """
  def deal_if_legal(game = %Game{status: :started}) do
    {:ok, Game.deal(game)}
  end
  def deal_if_legal(game) do
    {{:error, "Game has already been dealt."}, game}
  end

  @doc ~S"""
  Calls `Game.hint/4` on `game`, if it represents a legal play.

  Returns `{reply, game}` where `reply` is `:ok` or `{:error, message}` and
  `game` is the changed or not `Game`.
  """
  def hint_if_legal(game = %Game{status: status}, _player, _to, _hint)
  when status != :playing do
    {{:error, "Hints can't be given at this time."}, game}
  end
  def hint_if_legal(game = %Game{turn: turn}, player, _to, _hint)
  when turn != player do
    {{:error, "It's not #{player}'s turn."}, game}
  end
  def hint_if_legal(game, player, player, _hint) do
    {{:error, "A player cannot give hints to themself."}, game}
  end
  def hint_if_legal(game = %Game{clocks: 0}, _player, _to, _hint) do
    {{:error, "There are no clocks available."}, game}
  end
  def hint_if_legal(game, player, to, hint) do
    if Map.has_key?(game.hands, to) do
      hand = game.hands |> Map.fetch!(to)
      matches =
        Enum.any?(hand, fn {color, value} -> hint == color or hint == value end)
      if matches do
        {:ok, Game.hint(game, player, to, hint)}
      else
        {{:error, "No tiles match that hint."}, game}
      end
    else
      {{:error, "#{to} isn't a valid player."}, game}
    end
  end

  @doc ~S"""
  Calls `Game.discard/3` on `game`, if it represents a legal play.

  Returns `{reply, game}` where `reply` is `:ok` or `{:error, message}` and
  `game` is the changed or not `Game`.
  """
  def discard_if_legal(game = %Game{status: status}, _player, _index)
  when status != :playing do
    {{:error, "Discards can't be made at this time."}, game}
  end
  def discard_if_legal(game = %Game{turn: turn}, player, _index)
  when turn != player do
    {{:error, "It's not #{player}'s turn."}, game}
  end
  def discard_if_legal(game, player, index) do
    hand_size = game.hands |> Map.fetch!(player) |> length
    if index in 0..(hand_size - 1) do
      {:ok, Game.discard(game, player, index)}
    else
      {{:error, "That's not a tile."}, game}
    end
  end

  @doc ~S"""
  Calls `Game.play/3` on `game`, if it represents a legal play.

  Returns `{reply, game}` where `reply` is `:ok` or `{:error, message}` and
  `game` is the changed or not `Game`.
  """
  def play_if_legal(game = %Game{status: status}, _player, _index)
  when status != :playing do
    {{:error, "Plays can't be made at this time."}, game}
  end
  def play_if_legal(game = %Game{turn: turn}, player, _index)
  when turn != player do
    {{:error, "It's not #{player}'s turn."}, game}
  end
  def play_if_legal(game, player, index) do
    hand_size = game.hands |> Map.fetch!(player) |> length
    if index in 0..(hand_size - 1) do
      {:ok, Game.play(game, player, index)}
    else
      {{:error, "That's not a tile."}, game}
    end
  end
end

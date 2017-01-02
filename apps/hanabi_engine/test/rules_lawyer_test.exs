defmodule RulesLawyerTest do
  use ExUnit.Case, async: true

  alias HanabiEngine.{Game, RulesLawyer}

  test "deals the game if it hasn't already been dealt" do
    game = Game.new(~w[A B])
    {reply, dealt_game} = RulesLawyer.deal_if_legal(game)
    assert reply == :ok
    assert dealt_game != game
  end

  describe "status" do
    test "won't double-deal a game" do
      dealt_game = Game.new(~w[A B]) |> Game.deal
      {reply, same_game} = RulesLawyer.deal_if_legal(dealt_game)
      assert reply == {:error, "Game has already been dealt."}
      assert same_game == dealt_game
    end

    test "can't give hints before the deal" do
      game = Game.new(~w[A B])
      {reply, same_game} = RulesLawyer.hint_if_legal(game, "A", "B", 4)
      assert reply == {:error, "Hints can't be given at this time."}
      assert same_game == game
    end

    test "can't discard before the deal" do
      game = Game.new(~w[A B])
      {reply, same_game} = RulesLawyer.discard_if_legal(game, "A", 0)
      assert reply == {:error, "Discards can't be made at this time."}
      assert same_game == game
    end

    test "can't play before the deal" do
      game = Game.new(~w[A B])
      {reply, same_game} = RulesLawyer.play_if_legal(game, "A", 0)
      assert reply == {:error, "Plays can't be made at this time."}
      assert same_game == game
    end
  end

  describe "moves" do
    setup do
      # Use a known deal for testing purposes:
      #
      # * A's hand:  `[green: 4, green: 3, white: 3, blue: 4, green: 1]`
      # * B's hand:  `[red: 4, blue: 5, red: 2, white: 4, blue: 2]`
      # * Top three draws:  `[green: 4, white: 4, red: 5, …]`
      :rand.seed(:exsplus, {1, 2, 3})

      game = Game.new(~w[A B])
      {:ok, game: Game.deal(game)}
    end

    test "gives a hint if legal", %{game: game} do
      {reply, game_with_hint} = RulesLawyer.hint_if_legal(game, "A", "B", 4)
      assert reply == :ok
      assert game_with_hint != game
    end

    test "won't give hint out of turn", %{game: game} do
      {reply, same_game} = RulesLawyer.hint_if_legal(game, "B", "A", 4)
      assert reply == {:error, "It's not B's turn."}
      assert same_game == game
    end

    test "won't give hint to the current player", %{game: game} do
      {reply, same_game} = RulesLawyer.hint_if_legal(game, "A", "A", 4)
      assert reply == {:error, "A player cannot give hints to themself."}
      assert same_game == game
    end

    test "won't give hint to an illegal player", %{game: game} do
      {reply, same_game} = RulesLawyer.hint_if_legal(game, "A", "Z", 4)
      assert reply == {:error, "Z isn't a valid player."}
      assert same_game == game
    end

    test "won't give hint without clocks", %{game: game} do
      game_without_clocks =
        Enum.reduce(1..4, game, fn _i, new_game ->
          new_game
          |> Game.hint("A", "B", 4)
          |> Game.hint("B", "A", 4)
        end)

      {reply, same_game} =
        RulesLawyer.hint_if_legal(game_without_clocks, "A", "B", 4)
      assert reply == {:error, "There are no clocks available."}
      assert same_game == game_without_clocks
    end

    test "won't give an illegal hint", %{game: game} do
      {reply, same_game} = RulesLawyer.hint_if_legal(game, "A", "B", 1)
      assert reply == {:error, "No tiles match that hint."}
      assert same_game == game
    end

    test "discards a tile if legal", %{game: game} do
      {reply, game_with_discard} = RulesLawyer.discard_if_legal(game, "A", 0)
      assert reply == :ok
      assert game_with_discard != game
    end

    test "won't discard out of turn", %{game: game} do
      {reply, same_game} = RulesLawyer.discard_if_legal(game, "B", 0)
      assert reply == {:error, "It's not B's turn."}
      assert same_game == game
    end

    test "won't discard beyond the hand size", %{game: game} do
      {reply, same_game} = RulesLawyer.discard_if_legal(game, "A", 5)
      assert reply == {:error, "That's not a tile."}
      assert same_game == game
    end

    test "plays a tile if legal", %{game: game} do
      {reply, game_with_play} = RulesLawyer.play_if_legal(game, "A", 0)
      assert reply == :ok
      assert game_with_play != game
    end

    test "won't play out of turn", %{game: game} do
      {reply, same_game} = RulesLawyer.play_if_legal(game, "B", 0)
      assert reply == {:error, "It's not B's turn."}
      assert same_game == game
    end

    test "won't play beyond the hand size", %{game: game} do
      {reply, same_game} = RulesLawyer.play_if_legal(game, "A", 5)
      assert reply == {:error, "That's not a tile."}
      assert same_game == game
    end
  end
end

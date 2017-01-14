defmodule GameTest do
  use ExUnit.Case, async: true

  alias HanabiEngine.Game

  test "a starting hand for two or three players is five cards" do
    two_player_game = Game.new(~w[A B]) |> Game.deal
    hand_size = two_player_game.hands |> Map.fetch!("A") |> length
    assert hand_size == 5
  end

  test "a starting hand for four or five players is four cards" do
    four_player_game = Game.new(~w[A B C D]) |> Game.deal
    hand_size = four_player_game.hands |> Map.fetch!("A") |> length
    assert hand_size == 4
  end

  test "conversion to a player's view discards unneeded fields" do
    view = Game.new(~w[A B]) |> Game.deal |> Game.to_player_view("A")
    assert not Map.has_key?(view, :__struct__)
    assert not Map.has_key?(view, :status)
    assert not Map.has_key?(view, :knowns)
    assert not Map.has_key?(view, :insights)
  end

  test "conversion to a player's view reduces the draw pile to a size" do
    view = Game.new(~w[A B]) |> Game.deal |> Game.to_player_view("A")
    assert view.draw_pile == 40
  end

  test "conversion to a player's view changes tuples into lists" do
    view = Game.new(~w[A B]) |> Game.deal |> Game.to_player_view("A")
    bs_hand = view.hands |> Map.fetch!("B")
    assert Enum.all?(bs_hand, &is_list/1)
  end

  test "conversion to a player's view hides a player's hand for knowns" do
    view = Game.new(~w[A B]) |> Game.deal |> Game.to_player_view("A")
    assert not Map.has_key?(view.hands, "A")
    assert view.my_data.hand == List.duplicate([nil, nil], 5)
  end

  test "conversion to a player's view hides knowns" do
    view = Game.new(~w[A B]) |> Game.deal |> Game.to_player_view("A")
    assert not Map.has_key?(view, :knowns)
  end

  test "conversion to a player's view adds a turn indicator" do
    game = Game.new(~w[A B]) |> Game.deal
    as_view = Game.to_player_view(game, "A")
    assert as_view.my_data.turn == true

    bs_view = Game.to_player_view(game, "B")
    assert bs_view.my_data.turn == false
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

    test "giving a color hint", %{game: game} do
      game_with_hint = Game.hint(game, "A", "B", :red)
      bs_knowns = Map.fetch!(game_with_hint.knowns, "B")
      hint = [{:red, nil}, {nil, nil}, {:red, nil}, {nil, nil}, {nil, nil}]
      assert bs_knowns == hint
    end

    test "giving a value hint", %{game: game} do
      game_with_hint = Game.hint(game, "A", "B", 4)
      bs_knowns = Map.fetch!(game_with_hint.knowns, "B")
      hint = [{nil, 4}, {nil, nil}, {nil, nil}, {nil, 4}, {nil, nil}]
      assert bs_knowns == hint
    end

    test "hints stack", %{game: game} do
      game_with_first_hint = Game.hint(game, "A", "B", :red)
      game_with_passed_turn = Game.hint(game_with_first_hint, "B", "A", 1)
      game_with_second_hint = Game.hint(game_with_passed_turn, "A", "B", 4)
      bs_knowns = Map.fetch!(game_with_second_hint.knowns, "B")
      hint = [{:red, 4}, {nil, nil}, {:red, nil}, {nil, 4}, {nil, nil}]
      assert bs_knowns == hint
    end

    test "giving a hint advances to the next turn", %{game: game} do
      game_with_hint = Game.hint(game, "A", "B", :red)
      assert game_with_hint.turn == "B"
    end

    test "giving a hint spends a clock", %{game: game} do
      game_with_hint = Game.hint(game, "A", "B", :red)
      assert game_with_hint.clocks == 7
    end

    test "discarding a tile replaces it with a draw when available",
      %{game: game} do
      game_after_discard = Game.discard(game, "A", 2)
      as_hand = game_after_discard.hands |> Map.fetch!("A")
      assert Enum.at(as_hand, 2) == {:green, 4}
      assert game_after_discard.discards == [white: 3]
      assert hd(game_after_discard.draw_pile) == {:white, 4}
    end

    test "discarding a tile replaces it with a blank when no draws are available",
         %{game: game} do
      game_without_draws =
        Enum.reduce(1..20, game, fn _i, new_game ->
          new_game
          |> Game.discard("A", 0)
          |> Game.discard("B", 0)
        end)
      assert game_without_draws.draw_pile == [ ]

      ending_game = Game.discard(game_without_draws, "A", 2)
      as_hand = ending_game.hands |> Map.fetch!("A")
      assert Enum.at(as_hand, 2) == {nil, nil}
    end

    test "discarding a tile advances to the next turn", %{game: game} do
      game_after_discard = Game.discard(game, "A", 2)
      assert game_after_discard.turn == "B"
    end

    test "discarding a tile restores spent clocks", %{game: game} do
      game_without_full_clocks = Game.hint(game, "A", "B", :red)
      assert game_without_full_clocks.clocks == 7

      game_with_full_clocks = Game.discard(game_without_full_clocks, "B", 2)
      assert game_with_full_clocks.clocks == 8

      game_with_still_full_clocks =
        Game.discard(game_with_full_clocks, "A", 2)
      assert game_with_still_full_clocks.clocks == 8
    end

    test "discarding a tile clears knowns for that tile", %{game: game} do
      game_with_hint = Game.hint(game, "A", "B", :red)
      bs_knowns = game_with_hint.knowns |> Map.fetch!("B")
      assert hd(bs_knowns) == {:red, nil}

      game_after_discard = Game.discard(game_with_hint, "B", 0)
      bs_knowns = game_after_discard.knowns |> Map.fetch!("B")
      assert hd(bs_knowns) == {nil, nil}
    end

    test "playing a tile replaces it with a draw when available",
      %{game: game} do
      game_after_play = Game.play(game, "A", 4)
      as_hand = game_after_play.hands |> Map.fetch!("A")
      assert Enum.at(as_hand, 4) == {:green, 4}
      assert game_after_play.fireworks.green == 1
      assert hd(game_after_play.draw_pile) == {:white, 4}
    end

    test "playing a tile replaces it with a blank when no draws are available",
         %{game: game} do
      game_without_draws =
        Enum.reduce(1..20, game, fn _i, new_game ->
          new_game
          |> Game.discard("A", 0)
          |> Game.discard("B", 0)
        end)
      assert game_without_draws.draw_pile == [ ]

      ending_game = Game.play(game_without_draws, "A", 4)
      as_hand = ending_game.hands |> Map.fetch!("A")
      assert Enum.at(as_hand, 4) == {nil, nil}
    end

    test "playing a tile advances to the next turn", %{game: game} do
      game_after_play = Game.play(game, "A", 4)
      assert game_after_play.turn == "B"
    end

    test "playing an illegal tile discards it spends a fuse", %{game: game} do
      game_with_full_fuses = Game.play(game, "A", 4)
      assert game_with_full_fuses.fuses == 3

      game_without_full_fuses = Game.play(game_with_full_fuses, "B", 0)
      assert game_without_full_fuses.discards == [red: 4]
      assert game_without_full_fuses.fuses == 2
    end

    test "playing a tile clears knowns for that tile", %{game: game} do
      game_with_hint = Game.hint(game, "A", "B", :red)
      bs_knowns = game_with_hint.knowns |> Map.fetch!("B")
      assert hd(bs_knowns) == {:red, nil}

      game_after_play = Game.play(game_with_hint, "B", 0)
      bs_knowns = game_after_play.knowns |> Map.fetch!("B")
      assert hd(bs_knowns) == {nil, nil}
    end

    test "playing a five restores a clock", %{game: game} do
      game_ready_for_five =
        [
          {:play, ["A", 4]},
          {:discard, ["B", 0]},
          {:discard, ["A", 2]},
          {:discard, ["B", 0]},
          {:discard, ["A", 2]},
          {:discard, ["B", 0]},
          {:discard, ["A", 3]},
          {:discard, ["B", 0]},
          {:discard, ["A", 3]},
          {:discard, ["B", 0]},
          {:discard, ["A", 3]},
          {:discard, ["B", 0]},
          {:discard, ["A", 3]},
          {:discard, ["B", 0]},
          {:discard, ["A", 3]},
          {:discard, ["B", 0]},
          {:discard, ["A", 3]},
          {:discard, ["B", 0]},
          {:discard, ["A", 3]},
          {:discard, ["B", 0]},
          {:discard, ["A", 3]},
          {:discard, ["B", 0]},
          {:play, ["A", 3]},
          {:discard, ["B", 0]},
          {:play, ["A", 1]},
          {:discard, ["B", 0]},
          {:play, ["A", 0]}
        ]
        |> Enum.reduce(game, fn {fun, args}, new_game ->
          apply(Game, fun, [new_game | args])
        end)
        |> Game.hint("B", "A", 5)
      game_after_five = Game.play(game_ready_for_five, "A", 2)
      assert game_after_five.clocks == game_ready_for_five.clocks + 1
    end
  end

  describe "insights" do
    setup do
      # Use a known deal for testing purposes:
      #
      # * A's hand:  `[green: 4, green: 3, white: 3, blue: 4, green: 1]`
      # * B's hand:  `[red: 4, blue: 5, red: 2, white: 4, blue: 2]`
      # * Top three draws:  `[green: 4, white: 4, red: 5, …]`
      :rand.seed(:exsplus, {1, 2, 3})

      game =
        Game.new(~w[A B])
        |> Game.deal
        |> Game.hint("A", "B", :red)
      {:ok, game: game}
    end

    test "giving a hint populates insights", %{game: game} do
      bs_insights = game.insights |> Map.fetch!("B")
      assert bs_insights == [
        [ ],
        ["Not red"],
        [ ],
        ["Not red"],
        ["Not red"]
      ]
    end

    test "discarding a tile resets insights", %{game: game} do
      game_after_discard = Game.discard(game, "B", 1)
      bs_insights = game_after_discard.insights |> Map.fetch!("B")
      assert bs_insights == [
        [ ],
        [ ],
        [ ],
        ["Not red"],
        ["Not red"]
      ]
    end

    test "playing a tile resets insights", %{game: game} do
      game_after_play = Game.play(game, "B", 4)
      bs_insights = game_after_play.insights |> Map.fetch!("B")
      assert bs_insights == [
        [ ],
        ["Not red"],
        [ ],
        ["Not red"],
        [ ]
      ]
    end

    test "player view includes my insights", %{game: game} do
      my_insights = Game.to_player_view(game, "B").my_data.insights
      assert my_insights == [
        [ ],
        ["Not red"],
        [ ],
        ["Not red"],
        ["Not red"]
      ]
    end
  end
end

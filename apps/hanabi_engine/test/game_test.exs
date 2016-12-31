defmodule GameTest do
  use ExUnit.Case, async: true

  alias HanabiEngine.Game

  test "starting hand sizes are based on the number of players" do
    two_player_game = Game.new(~w[A B]) |> Game.deal
    hand_size = two_player_game.hands |> Map.fetch!("A") |> length
    assert hand_size == 5

    four_player_game = Game.new(~w[A B C D]) |> Game.deal
    hand_size = four_player_game.hands |> Map.fetch!("A") |> length
    assert hand_size == 4
  end

  describe "moves" do
    setup do
      game = Game.new(~w[A B])
      {:ok, game: Game.deal(game)}
    end

    test "giving a hint", %{game: game} do
      bs_hand = Map.fetch!(game.hands, "B")
      hint_color = bs_hand |> hd |> elem(0)
      hint = Enum.map(bs_hand, fn {tile_color, _} ->
        if tile_color == hint_color do
          {hint_color, nil}
        else
          {nil, nil}
        end
      end)
      game_with_hint = Game.hint(game, "A", "B", hint_color)
      assert Map.fetch!(game_with_hint.knowns, "B") == hint
      assert game_with_hint.turn == "B"
      assert game_with_hint.clocks == 7

      # value = Enum.find(1..5, fn n -> GameManager.hint(game, "B", "A", n) == :ok end)
      # assert_receive {
      #   :hint,
      #   "B",
      #   %{
      #     to: "A",
      #     color: [nil, nil, nil, nil, nil],
      #     value: positions,
      #     next_turn: "A",
      #     new_clocks: 6
      #   }
      # }
      # assert Enum.find(positions, fn position -> position == value end)
    end

    test "discarding a tile", %{game: game} do
      # spend a clock
      hint = game.hands |> Map.fetch!("B") |> hd |> elem(0)
      game_with_hint = Game.hint(game, "A", "B", hint)
      assert game_with_hint.clocks == 7

      discard = game_with_hint.hands |> Map.fetch!("B") |> Enum.at(1)
      game_after_discard = Game.discard(game_with_hint, "B", 1)
      bs_hand = game_after_discard.hands |> Map.fetch!("B")
      assert hd(game_after_discard.discards) == discard
      assert hd(game_with_hint.draw_pile) == Enum.at(bs_hand, 1)
      assert hd(game_with_hint.draw_pile) != hd(game_after_discard.draw_pile)
      assert game_after_discard.turn == "A"
      assert game_after_discard.clocks == 8

      # :ok = GameManager.discard(game, "A", 0)
      # assert_receive {
      #   :discard,
      #   "A",
      #   %{
      #     discarded: unknown,
      #     drawn: drawn,
      #     new_draw_pile: 38,
      #     next_turn: "B",
      #     new_clocks: 8
      #   }
      # }
      # assert is_tuple(unknown) and
      #        tuple_size(unknown) == 2 and
      #        elem(unknown, 0) in ~w[blue green red white yellow]a and
      #        elem(unknown, 1) in 1..5
      # assert is_tuple(drawn) and
      #        tuple_size(drawn) == 2 and
      #        elem(drawn, 0) in ~w[blue green red white yellow]a and
      #        elem(drawn, 1) in 1..5
    end

    test "playing a tile", %{game: game} do
      hand = game.hands |> Map.fetch!("A")
      tile = Enum.find(hand, hd(hand), fn {_, value} -> value == 1 end)
      color = elem(tile, 0)
      index = Enum.find_index(hand, fn other_tile -> tile == other_tile end)
      game_after_play = Game.play(game, "A", index)
      new_hand = game_after_play.hands |> Map.fetch!("A")
      assert hd(game.draw_pile) == Enum.at(new_hand, index)
      assert hd(game.draw_pile) != hd(game_after_play.draw_pile)
      assert game_after_play.turn == "B"
      if elem(tile, 1) == 1 do
        assert Map.fetch!(game_after_play.fireworks, color) == elem(tile, 1)
        assert game.discards == game_after_play.discards
        assert game.fuses == game_after_play.fuses
      else
        assert game.fireworks == game_after_play.fireworks
        assert game_after_play.discards == [tile | game.discards]
        assert game_after_play.fuses == game.fuses - 1
      end

      # bs_hand = details.hands |> Map.fetch!("B")
      # legal_play =
      #   Enum.find(bs_hand, fn tile ->
      #     tile != first_play and elem(tile, 1) == 1
      #   end)
      # second_discard = if legal_play, do: nil, else: hd(bs_hand)
      # index = Enum.find_index(bs_hand, fn tile -> legal_play == tile end)
      # :ok = GameManager.play(game, "B", index || 0)
      # assert_receive {
      #   :play,
      #   "B",
      #   %{
      #     played: ^legal_play,
      #     discarded: ^second_discard,
      #     drawn: drawn,
      #     new_draw_pile: 38,
      #     next_turn: "A",
      #     new_clocks: 8,
      #     new_fuses: second_fuses
      #   }
      # }
      # assert is_tuple(drawn) and
      #        tuple_size(drawn) == 2 and
      #        elem(drawn, 0) in ~w[blue green red white yellow]a and
      #        elem(drawn, 1) in 1..5
      # if is_tuple(legal_play) do
      #   assert tuple_size(legal_play) == 2 and
      #          elem(legal_play, 0) in ~w[blue green red white yellow]a and
      #          elem(legal_play, 1) in 1..5
      #   assert is_nil(second_discard)
      #   assert second_fuses == first_fuses
      # else
      #   assert is_nil(legal_play)
      #   assert tuple_size(second_discard) == 2 and
      #          elem(second_discard, 0) in ~w[blue green red white yellow]a and
      #          elem(second_discard, 1) in 1..5
      #   assert second_fuses == first_fuses - 1
      # end
    end
  end
end

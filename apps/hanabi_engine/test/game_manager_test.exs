defmodule GameManagerTest do
  use ExUnit.Case, async: true

  alias Phoenix.PubSub
  alias HanabiEngine.{GameManager, GameSupervisor}

  test "games are started under dynamic supervision" do
    before_children = Supervisor.which_children(GameSupervisor)

    started = GameManager.start("TestSupervision", ~w[FirstPlayer SecondPlayer])
    assert(
      is_tuple(started) and elem(started, 0) == :ok and is_pid(elem(started, 1))
    )

    after_children = Supervisor.which_children(GameSupervisor)
    {:ok, supervised_game} = started
    child = {:undefined, supervised_game, :worker, [GameManager]}
    assert not child in before_children
    assert child in after_children
  end

  test "games can be initialized with a seed to make them reproducible" do
    {:ok, seeded_game} = GameManager.start("TestSeed", ~w[A B], {1, 2, 3})
    PubSub.subscribe(:hanabi, "game:TestSeed:A")
    GameManager.deal(seeded_game)
    assert_receive {
      :deal,
      "A",
      %{hands: %{"B" => [red: 4, blue: 5, red: 2, white: 4, blue: 2]}}
    }
  end

  test "the initial deal publishes the game setup for each player" do
    players = ~w[A B]
    {:ok, new_game} = GameManager.start("TestDeal", players)
    PubSub.subscribe(:hanabi, "game:TestDeal:A")
    GameManager.deal(new_game)
    assert_receive {
      :deal,
      "A",
      %{
        players: ^players,
        hands: %{"A" => 5, "B" => bs_hand},
        new_draw_pile: 40,
        discards: [ ],
        fireworks: %{blue: nil, green: nil, red: nil, white: nil, yellow: nil},
        next_turn: "A",
        new_clocks: 8,
        new_fuses: 3
      }
    } when is_list(bs_hand) and length(bs_hand) == 5
  end

  test "starting hand sizes are based on the number of players" do
    {:ok, two_player_game} = GameManager.start("TestTwoPlayerHand", ~w[A B])
    PubSub.subscribe(:hanabi, "game:TestTwoPlayerHand:A")
    GameManager.deal(two_player_game)
    assert_receive {:deal, "A", %{hands: %{"A" => 5}}}

    {:ok, four_player_game} = GameManager.start("TestFourPlayerHand", ~w[A B C D])
    PubSub.subscribe(:hanabi, "game:TestFourPlayerHand:A")
    GameManager.deal(four_player_game)
    assert_receive {:deal, "A", %{hands: %{"A" => 4}}}
  end

  describe "moves" do
    setup do
      game_id = UUID.uuid1
      {:ok, game} = GameManager.start(game_id, ~w[A B])
      PubSub.subscribe(:hanabi, "game:#{game_id}:A")
      GameManager.deal(game)
      details =
        receive do
          {:deal, "A", deal} -> deal
        after
          100 -> raise "Hand not received within 100ms."
        end
      {:ok, game: game, details: details}
    end

    test "giving a hint", %{game: game, details: details} do
      bs_hand = Map.fetch!(details.hands, "B")
      hint_color = bs_hand |> hd |> elem(0)
      hint = Enum.map(bs_hand, fn {tile_color, _} ->
        if tile_color == hint_color do
          hint_color
        else
          nil
        end
      end)
      :ok = GameManager.hint(game, "A", "B", hint_color)
      assert_receive {
        :hint,
        "A",
        %{
          to: "B",
          color: ^hint,
          value: [nil, nil, nil, nil, nil],
          next_turn: "B",
          new_clocks: 7
        }
      }

      value = Enum.find(1..5, fn n -> GameManager.hint(game, "B", "A", n) == :ok end)
      assert_receive {
        :hint,
        "B",
        %{
          to: "A",
          color: [nil, nil, nil, nil, nil],
          value: positions,
          next_turn: "A",
          new_clocks: 6
        }
      }
      assert Enum.find(positions, fn position -> position == value end)
    end

    test "discarding a tile", %{game: game, details: details} do
      # spend a clock
      Enum.find(1..5, fn n -> GameManager.hint(game, "A", "B", n) == :ok end)
      assert_receive {:hint, "A", %{new_clocks: 7}}

      discard = details.hands |> Map.fetch!("B") |> Enum.at(1)
      :ok = GameManager.discard(game, "B", 1)
      assert_receive {
        :discard,
        "B",
        %{
          discarded: ^discard,
          drawn: drawn,
          new_draw_pile: 39,
          next_turn: "A",
          new_clocks: 8
        }
      }
      assert is_tuple(drawn) and
             tuple_size(drawn) == 2 and
             elem(drawn, 0) in ~w[blue green red white yellow]a and
             elem(drawn, 1) in 1..5

      :ok = GameManager.discard(game, "A", 0)
      assert_receive {
        :discard,
        "A",
        %{
          discarded: unknown,
          drawn: drawn,
          new_draw_pile: 38,
          next_turn: "B",
          new_clocks: 8
        }
      }
      assert is_tuple(unknown) and
             tuple_size(unknown) == 2 and
             elem(unknown, 0) in ~w[blue green red white yellow]a and
             elem(unknown, 1) in 1..5
      assert is_tuple(drawn) and
             tuple_size(drawn) == 2 and
             elem(drawn, 0) in ~w[blue green red white yellow]a and
             elem(drawn, 1) in 1..5
    end

    test "playing a tile", %{game: game, details: details} do
      :ok = GameManager.play(game, "A", 0)
      assert_receive {
        :play,
        "A",
        %{
          played: first_play,
          discarded: first_discard,
          drawn: drawn,
          new_draw_pile: 39,
          next_turn: "B",
          new_clocks: 8,
          new_fuses: first_fuses
        }
      }
      assert is_tuple(drawn) and
             tuple_size(drawn) == 2 and
             elem(drawn, 0) in ~w[blue green red white yellow]a and
             elem(drawn, 1) in 1..5
      if is_tuple(first_play) do
        assert tuple_size(first_play) == 2 and
               elem(first_play, 0) in ~w[blue green red white yellow]a and
               elem(first_play, 1) in 1..5
        assert is_nil(first_discard)
        assert first_fuses == 3
      else
        assert is_nil(first_play)
        assert tuple_size(first_discard) == 2 and
               elem(first_discard, 0) in ~w[blue green red white yellow]a and
               elem(first_discard, 1) in 1..5
        assert first_fuses == 2
      end

      bs_hand = details.hands |> Map.fetch!("B")
      legal_play =
        Enum.find(bs_hand, fn tile ->
          tile != first_play and elem(tile, 1) == 1
        end)
      second_discard = if legal_play, do: nil, else: hd(bs_hand)
      index = Enum.find_index(bs_hand, fn tile -> legal_play == tile end)
      :ok = GameManager.play(game, "B", index || 0)
      assert_receive {
        :play,
        "B",
        %{
          played: ^legal_play,
          discarded: ^second_discard,
          drawn: drawn,
          new_draw_pile: 38,
          next_turn: "A",
          new_clocks: 8,
          new_fuses: second_fuses
        }
      }
      assert is_tuple(drawn) and
             tuple_size(drawn) == 2 and
             elem(drawn, 0) in ~w[blue green red white yellow]a and
             elem(drawn, 1) in 1..5
      if is_tuple(legal_play) do
        assert tuple_size(legal_play) == 2 and
               elem(legal_play, 0) in ~w[blue green red white yellow]a and
               elem(legal_play, 1) in 1..5
        assert is_nil(second_discard)
        assert second_fuses == first_fuses
      else
        assert is_nil(legal_play)
        assert tuple_size(second_discard) == 2 and
               elem(second_discard, 0) in ~w[blue green red white yellow]a and
               elem(second_discard, 1) in 1..5
        assert second_fuses == first_fuses - 1
      end
    end
  end
end

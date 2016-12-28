defmodule GameTest do
  use ExUnit.Case, async: true

  alias Phoenix.PubSub
  alias HanabiEngine.{Game, GameSupervisor}

  test "games are started under dynamic supervision" do
    before_children = Supervisor.which_children(GameSupervisor)

    started = Game.start("TestSupervision", ~w[FirstPlayer SecondPlayer])
    assert(
      is_tuple(started) and elem(started, 0) == :ok and is_pid(elem(started, 1))
    )

    after_children = Supervisor.which_children(GameSupervisor)
    {:ok, supervised_game} = started
    child = {:undefined, supervised_game, :worker, [Game]}
    assert not child in before_children
    assert child in after_children
  end

  test "games can be initialized with a seed to make them reproducible" do
    {:ok, seeded_game} = Game.start("TestSeed", ~w[A B], {1, 2, 3})
    PubSub.subscribe(:hanabi, "game:TestSeed:A")
    Game.deal(seeded_game)
    assert_receive {
      :deal,
      "A",
      %{hands: %{"B" => [red: 4, blue: 5, red: 2, white: 4, blue: 2]}}
    }
  end

  test "the initial deal publishes the game setup for each player" do
    players = ~w[A B]
    {:ok, new_game} = Game.start("TestDeal", players)
    PubSub.subscribe(:hanabi, "game:TestDeal:A")
    Game.deal(new_game)
    assert_receive {
      :deal,
      "A",
      %{
        players: ^players,
        hands: %{"A" => 5, "B" => bs_hand},
        new_draw_pile: 40,
        discards: [ ],
        next_turn: "A",
        new_clocks: 8,
        new_fuses: 3
      }
    } when is_list(bs_hand) and length(bs_hand) == 5
  end

  test "starting hand sizes are based on the number of players" do
    {:ok, two_player_game} = Game.start("TestTwoPlayerHand", ~w[A B])
    PubSub.subscribe(:hanabi, "game:TestTwoPlayerHand:A")
    Game.deal(two_player_game)
    assert_receive {:deal, "A", %{hands: %{"A" => 5}}}

    {:ok, four_player_game} = Game.start("TestFourPlayerHand", ~w[A B C D])
    PubSub.subscribe(:hanabi, "game:TestFourPlayerHand:A")
    Game.deal(four_player_game)
    assert_receive {:deal, "A", %{hands: %{"A" => 4}}}
  end
end

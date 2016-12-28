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

  test "starting hand sizes are based on the number of players" do
    {:ok, two_player_game} = Game.start("TestTwoPlayerHand", ~w[A B])
    PubSub.subscribe(:hanabi, "game:TestTwoPlayerHand:A")
    Game.deal(two_player_game)
    assert_receive {:dealt, hand} when length(hand) == 5

    {:ok, four_player_game} = Game.start("TestFourPlayerHand", ~w[A B C D])
    PubSub.subscribe(:hanabi, "game:TestFourPlayerHand:A")
    Game.deal(four_player_game)
    assert_receive {:dealt, hand} when length(hand) == 4
  end

  test "games can be initialized with a seed to make them reproducible" do
    {:ok, seeded_game} = Game.start("TestSeed", ~w[A B], {1, 2, 3})
    PubSub.subscribe(:hanabi, "game:TestSeed:A")
    Game.deal(seeded_game)
    assert_receive {:dealt, green: 4, green: 3, white: 3, blue: 4, green: 1}
  end
end

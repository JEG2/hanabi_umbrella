defmodule GameTest do
  use ExUnit.Case, async: true

  alias HanabiEngine.{Game, GameSupervisor}

  test "games are started under dynamic supervision" do
    before_children = Supervisor.which_children(GameSupervisor)

    started = Game.start(["First Player", "Second Player"])
    assert(
      is_tuple(started) and elem(started, 0) == :ok and is_pid(elem(started, 1))
    )

    after_children = Supervisor.which_children(GameSupervisor)
    {:ok, game} = started
    child = {:undefined, game, :worker, [Game]}
    assert not child in before_children
    assert child in after_children
  end
end

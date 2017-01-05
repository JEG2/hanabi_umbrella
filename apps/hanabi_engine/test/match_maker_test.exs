defmodule MatchMakerTest do
  use ExUnit.Case, async: true

  alias HanabiEngine.MatchMaker

  test "new users are registered by process" do
    assert is_nil(MatchMaker.user("NewUser"))
    assert MatchMaker.register("NewUser") == :ok
    assert MatchMaker.user("NewUser") == self
  end

  test "registration fails if a username is unavailable" do
    assert MatchMaker.register("JustOne") == :ok
    assert MatchMaker.register("JustOne") == {:error, "User name unavailable."}
  end

  test "users are unregistered on disconnect" do
    test = self
    {user, ref} = spawn_monitor(fn ->
      MatchMaker.register("Temp")
      send(test, :registered)
      receive do
        :finish -> :ok
      end
    end)

    assert_receive :registered
    assert not is_nil(MatchMaker.user("Temp"))

    send(user, :finish)
    assert_receive {:DOWN, ^ref, :process, ^user, :normal}
    MatchMaker.register("AfterTemp")  # ensure it has processed DOWN message
    assert is_nil(MatchMaker.user("Temp"))
  end

  test "a game is started as needed on join" do
    assert MatchMaker.register("LoneGamer") == :ok
    assert(
      MatchMaker.join_game("LoneGamer", 4) == {:waiting, %{"LoneGamer" => self}}
    )
  end

  test "existing games are joined" do
    test = self
    pid = spawn(fn ->
      MatchMaker.register("FirstPlayer")
      MatchMaker.join_game("FirstPlayer", 3)
      send(test, :joined)
      receive do
        :finish -> :ok
      end
    end)

    assert_receive :joined
    assert MatchMaker.register("SecondPlayer") == :ok
    players = {:waiting, %{"FirstPlayer" => pid, "SecondPlayer" => self}}
    assert MatchMaker.join_game("SecondPlayer", 3) == players
  end

  test "filling a game removes it" do
    test = self
    pid = spawn(fn ->
      MatchMaker.register("PlayerOne")
      MatchMaker.join_game("PlayerOne", 2)
      send(test, :joined)
      receive do
        :finish -> :ok
      end
    end)

    assert_receive :joined
    assert MatchMaker.register("PlayerTwo") == :ok
    players = {:ready, %{"PlayerOne" => pid, "PlayerTwo" => self}}
    assert MatchMaker.join_game("PlayerTwo", 2) == players

    players = {:waiting, %{"PlayerTwo" => self}}
    assert MatchMaker.join_game("PlayerTwo", 2) == players
  end

  test "games are left on disconnect" do
    test = self
    {user, ref} = spawn_monitor(fn ->
      MatchMaker.register("TempPlayer")
      MatchMaker.join_game("TempPlayer", 5)
      send(test, :joined)
      receive do
        :finish -> :ok
      end
    end)

    assert_receive :joined
    send(user, :finish)
    assert_receive {:DOWN, ^ref, :process, ^user, :normal}
    MatchMaker.register("AfterTempPlayer")  # ensure it has processed DOWN message
    players = {:waiting, %{"AfterTempPlayer" => self}}
    assert MatchMaker.join_game("AfterTempPlayer", 5) == players
  end

  test "you cannot join a game with an invalid number of players" do
    assert MatchMaker.register("BadCount") == :ok
    assert(
      MatchMaker.join_game("BadCount", 6) == {:error, "Invalid player count."}
    )
  end

  test "you must be the named user to join a game" do
    error = {:error, "You can only add your user to games."}
    assert MatchMaker.register("Me") == :ok
    assert MatchMaker.join_game("NotMe", 2) == error
  end
end

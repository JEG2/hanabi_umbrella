defmodule GameManagerTest do
  use ExUnit.Case, async: true

  alias HanabiEngine.{GameManager, GameSupervisor}

  test "starts new games with an ID and seed" do
    players = ~w[A B]
    {:ok, id, ^players, seed} = GameManager.start_new(players)
    assert is_binary(id) and byte_size(id) > 0
    assert(
      is_tuple(seed) and is_atom(elem(seed, 0)) and is_list(elem(seed, 1)) and
      is_integer(hd(elem(seed, 1))) and is_integer(tl(elem(seed, 1)))
    )
  end

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

  test "the initial deal is triggered by publishing the named message" do
    {:ok, _game} = GameManager.start("TestDeal", ~w[A B])
    GameManager.subscribe("TestDeal")
    GameManager.deal("TestDeal")
    assert_receive {:deal, :ok, "TestDeal", game}
    assert length(game.draw_pile) == 40
  end

  test "games can be initialized with a seed to make them reproducible" do
    seed = :rand.seed_s(:exsplus, {1, 2, 3}) |> :rand.export_seed_s
    {:ok, _game} = GameManager.start("TestSeed", ~w[A B], seed)
    GameManager.subscribe("TestSeed")
    GameManager.deal("TestSeed")
    assert_receive {:deal, :ok, "TestSeed", game}
    bs_hand = game.hands |> Map.fetch!("B")
    assert bs_hand == [red: 4, blue: 5, red: 2, white: 4, blue: 2]
  end

  describe "moves" do
    setup do
      game_id = UUID.uuid1
      # Use a known deal for testing purposes:
      #
      # * A's hand:  `[green: 4, green: 3, white: 3, blue: 4, green: 1]`
      # * B's hand:  `[red: 4, blue: 5, red: 2, white: 4, blue: 2]`
      # * Top three draws:  `[green: 4, white: 4, red: 5, …]`
      seed = :rand.seed_s(:exsplus, {1, 2, 3}) |> :rand.export_seed_s
      {:ok, _game} = GameManager.start(game_id, ~w[A B], seed)
      GameManager.subscribe(game_id)
      GameManager.deal(game_id)
      assert_receive {:deal, :ok, ^game_id, game}
      {:ok, id: game_id, game: game}
    end

    test "hints are given by publishing the named message", %{id: id} do
      GameManager.hint(id, "A", "B", :red)
      assert_receive {{:hint, "A", "B", :red}, :ok, ^id, game}
      bs_knowns = game.knowns |> Map.fetch!("B")
      hint = [{:red, nil}, {nil, nil}, {:red, nil}, {nil, nil}, {nil, nil}]
      assert bs_knowns == hint
    end

    test "discards are made by publishing the named message", %{id: id} do
      GameManager.discard(id, "A", 0)
      assert_receive {{:discard, "A", 0}, :ok, ^id, game}
      assert game.discards == [green: 4]
    end

    test "plays are made by publishing the named message", %{id: id} do
      GameManager.play(id, "A", 4)
      assert_receive {{:play, "A", 4}, :ok, ^id, game}
      assert game.fireworks.green == 1
    end

    test "illegal moves receive an error reply and an unchanged game",
         %{id: id, game: dealt_game} do
      GameManager.hint(id, "B", "A", 1)
      assert_receive {
        {:hint, "B", "A", 1},
        {:error, "It's not B's turn."},
        ^id,
        game
      }
      assert dealt_game == game
    end
  end
end

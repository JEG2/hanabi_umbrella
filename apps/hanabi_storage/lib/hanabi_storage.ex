defmodule HanabiStorage do
  import Ecto.Query, only: [from: 2]
  alias HanabiStorage.{Game, Move, Repo}

  def most_recent_game_event_for(players) do
    query =
      from g in Game,
        where: g.players == ^players,
        order_by: [desc: :inserted_at],
        limit: 1
    game =
      query
      |> Repo.one
      |> Repo.preload(:moves)

    # A bug in Ecto?
    if game do
      moves =
        Enum.map(game.moves, fn move ->
          if is_binary(move.arguments) do
            %Move{
              game_id: move.game_id,
              play: move.play,
              arguments: :erlang.binary_to_term(move.arguments),
              inserted_at: move.inserted_at
            }
          else
            move
          end
        end)
      %Game{game | moves: moves}
    else
      game
    end
  end

  def load(players) do
    case most_recent_game_event_for(players) do
      saved_game = %HanabiStorage.Game{event: "started"} ->
        new_game =
          players
          |> HanabiEngine.Game.new
          |> HanabiEngine.Game.deal
        Enum.reduce(saved_game.moves, new_game, fn move, game ->
          apply(
            HanabiEngine.Game,
            String.to_atom(move.play),
            [game | move.arguments]
          )
        end)
      _ ->
        HanabiEngine.Game.new(players)
    end
  end
end

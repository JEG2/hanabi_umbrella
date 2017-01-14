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
end

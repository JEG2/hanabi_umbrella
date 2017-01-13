defmodule HanabiStorage do
  import Ecto.Query, only: [from: 2]
  alias HanabiStorage.{Game, Repo}

  def most_recent_game_event_for(players) do
    query =
      from g in Game,
        where: g.players == ^players,
        order_by: [desc: :inserted_at],
        limit: 1
    query
    |> Repo.one
    |> Repo.preload(:moves)
  end
end

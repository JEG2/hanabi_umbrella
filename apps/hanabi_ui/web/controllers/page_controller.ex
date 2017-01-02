defmodule HanabiUi.PageController do
  use HanabiUi.Web, :controller

  alias HanabiEngine.Game

  def index(conn, _params) do
    game =
      Game.new(~w[James Paul])
      |> Game.deal
      |> Game.to_player_view("Paul")

    conn
    |> assign(:game, game)
    |> render("index.html")
  end
end

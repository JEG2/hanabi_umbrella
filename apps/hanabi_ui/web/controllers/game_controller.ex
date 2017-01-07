defmodule HanabiUi.GameController do
  use HanabiUi.Web, :controller

  def index(conn, _params) do
    conn
    |> render("index.html")
  end
end

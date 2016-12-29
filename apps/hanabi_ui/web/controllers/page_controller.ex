defmodule HanabiUi.PageController do
  use HanabiUi.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end

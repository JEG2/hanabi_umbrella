defmodule HanabiUi.GameView do
  use HanabiUi.Web, :view

  def host_with_port(conn) do
    host = conn.host
    port = conn.port || 80
    "#{host}:#{port}"
  end
end

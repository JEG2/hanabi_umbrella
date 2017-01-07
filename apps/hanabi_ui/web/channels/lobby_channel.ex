defmodule HanabiUi.LobbyChannel do
  use Phoenix.Channel

  def join("game:lobby", _message, socket) do
    {:ok, socket}
  end
  def join(_topic, _params, _socket) do
    {:error, %{reason: "no such topic"}}
  end

  def handle_in("register", %{"userName" => user_name}, socket) do
    result =
      case HanabiEngine.MatchMaker.register(user_name) do
        :ok ->
          {
            :ok,
            %{
              success: true,
              userName: user_name,
              message: "Registered as #{user_name}"
            }
          }
        {:error, message} ->
          {:ok, %{success: false, userName: user_name, message: message}}
      end
    {:reply, result, socket}
  end

  def handle_in("join", %{"userName" => user_name, "playerCount" => player_count}, socket) do
    result =
      case HanabiEngine.MatchMaker.join_game(user_name, String.to_integer(player_count)) do
        {:ready, players} ->
          {
            :ok,
            %{
              success: true,
              userName: user_name,
              message: "You are waiting for a game."
            }
          }
        {:waiting, players} ->
          {
            :ok,
            %{
              success: true,
              userName: user_name,
              message: "You are waiting for a game."
            }
          }
        {:error, message} ->
          {:ok, %{success: false, userName: user_name, message: message}}
      end
    {:reply, result, socket}
  end

end

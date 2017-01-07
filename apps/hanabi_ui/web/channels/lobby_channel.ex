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
end

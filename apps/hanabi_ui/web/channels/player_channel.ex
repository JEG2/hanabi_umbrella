defmodule HanabiUi.PlayerChannel do
  use Phoenix.Channel
  require Logger

  def join("game:player", _message, socket) do
    Phoenix.PubSub.subscribe(:players, "player:#{socket.assigns.uuid}")
    {:ok, socket}
  end
  def join(_topic, _params, _socket), do: {:error, %{reason: "no such topic"}}

  def handle_in("discard", %{"userName" => user_name, "idx" => idx}, socket) do
    HanabiEngine.GameManager.discard(socket.assigns.game_id, user_name, idx)
    {:noreply, socket}
  end
  def handle_in("play", %{"userName" => user_name, "idx" => idx}, socket) do
    HanabiEngine.GameManager.play(socket.assigns.game_id, user_name, idx)
    {:noreply, socket}
  end

  def handle_info({:deal, :ok, _game_id, game}, socket) do
    update_game_ui(game, socket)
    {:noreply, socket}
  end
  def handle_info({{:discard, _user_name, _idx}, :ok, _game_id, game}, socket) do
    update_game_ui(game, socket)
    {:noreply, socket}
  end
  def handle_info({{:play, _user_name, _idx}, :ok, _game_id, game}, socket) do
    update_game_ui(game, socket)
    {:noreply, socket}
  end

  def handle_info({:game_started, uuid, user_name, game_id, pid}, socket) do
    new_socket =
      if socket.assigns.uuid == uuid do
        HanabiEngine.GameManager.subscribe(game_id)
        send(pid, :player_acknowledgement)
        socket
        |> assign(:user_name, user_name)
        |> assign(:game_id, game_id)
      else
        socket
      end
    {:noreply, new_socket}
  end

  def handle_info(message, socket) do
    Logger.debug "Unexpected message:  #{inspect message}"
    {:noreply, socket}
  end

  ### Helpers ###

  defp update_game_ui(game, socket) do
    push(
      socket,
      "game",
      HanabiEngine.Game.to_player_view(game, socket.assigns.user_name)
    )
  end
end

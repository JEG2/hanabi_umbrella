defmodule HanabiUi.PlayerChannel do
  use Phoenix.Channel

  ### Registration ###

  def join("game:player", _message, socket), do: {:ok, socket}
  def join(_topic, _params, _socket), do: {:error, %{reason: "no such topic"}}

  def handle_in("register", %{"userName" => user_name}, socket) do
    {new_socket, result} =
      case HanabiEngine.MatchMaker.register(user_name) do
        :ok ->
          {
            assign(socket, :user_name, user_name),
            succeed(user_name, "Registered as #{user_name}")
          }
        {:error, message} ->
          {socket, fail(user_name, message)}
      end
    {:reply, result, new_socket}
  end

  def handle_in(
    "join",
    %{"userName" => user_name, "playerCount" => player_count},
    socket
  ) do
    result =
      case HanabiEngine.MatchMaker.join_game(user_name, player_count) do
        {:ready, players} ->
          start_game(players)
          succeed(user_name, "You are waiting for a game.")
        {:waiting, _players} ->
          succeed(user_name, "You are waiting for a game.")
        {:error, message} ->
          {:ok, fail(user_name, message)}
      end
    {:reply, result, socket}
  end

  ### Gameplay ###

  def handle_in("discard", %{"userName" => user_name, "idx" => idx}, socket) do
    HanabiEngine.GameManager.discard(socket.assigns.game_id, user_name, idx)
    {:noreply, socket}
  end
  def handle_in("play", %{"userName" => user_name, "idx" => idx}, socket) do
    HanabiEngine.GameManager.play(socket.assigns.game_id, user_name, idx)
    {:noreply, socket}
  end

  def handle_info({:deal, :ok, game}, socket) do
    update_game_ui(game, socket)
    {:noreply, socket}
  end
  def handle_info({{:discard, _user_name, _idx}, :ok, game}, socket) do
    update_game_ui(game, socket)
    {:noreply, socket}
  end
  def handle_info({{:play, _user_name, _idx}, :ok, game}, socket) do
    update_game_ui(game, socket)
    {:noreply, socket}
  end

  ### Registration ###

  def handle_info({:game_started, game_id}, socket) do
    HanabiEngine.GameManager.subscribe(game_id)
    new_socket = assign(socket, :game_id, game_id)
    {:noreply, new_socket}
  end
  def handle_info({:game_start_error, message, player_name}, socket) do
    push(socket, "game_start_error", fail(player_name, message))
    {:noreply, socket}
  end

  ### Helpers ###

  defp succeed(user_name, message) do
    {:ok, %{success: true, userName: user_name, message: message}}
  end

  defp fail(user_name, message) do
    {:ok, %{success: false, userName: user_name, message: message}}
  end

  defp start_game(players) do
    result = HanabiEngine.GameManager.start_new(Map.keys(players))
    case result do
      {:ok, game_id, _player_names, _seed} ->
        Enum.each(players, fn {_player_name, pid} ->
          send(pid, {:game_started, game_id})
        end)
        HanabiEngine.GameManager.deal(game_id)
      {:error, message} ->
        Enum.each(players, fn {player_name, pid} ->
          send(pid, {:game_start_error, message, player_name})
        end)
    end
  end

  defp update_game_ui(game, socket) do
    push(
      socket,
      "game",
      HanabiEngine.Game.to_player_view(game, socket.assigns.user_name)
    )
  end
end

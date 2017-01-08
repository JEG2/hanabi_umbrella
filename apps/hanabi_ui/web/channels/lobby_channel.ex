defmodule HanabiUi.LobbyChannel do
  use Phoenix.Channel

  def join("game:lobby", _message, socket) do
    {:ok, socket}
  end
  def join(_topic, _params, _socket) do
    {:error, %{reason: "no such topic"}}
  end

  def handle_in("register", %{"userName" => user_name}, socket) do
    {new_socket, result} =
      case HanabiEngine.MatchMaker.register(user_name) do
        :ok ->
          {assign(socket, :user_name, user_name),
          {
            :ok,
            %{
              success: true,
              userName: user_name,
              message: "Registered as #{user_name}"
            }
          }}
        {:error, message} ->
          {socket, {:ok, %{success: false, userName: user_name, message: message}}}
      end
    {:reply, result, new_socket}
  end

  def handle_in("join", %{"userName" => user_name, "playerCount" => player_count}, socket) do
    result =
      case HanabiEngine.MatchMaker.join_game(user_name, String.to_integer(player_count)) do
        {:ready, players} ->
          start_game(players)

          {
            :ok,
            %{
              success: true,
              userName: user_name,
              message: "You are waiting for a game."
            }
          }
        {:waiting, _players} ->
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

  def handle_in("discard", %{"userName" => user_name, "idx" => idx}, socket) do
    HanabiEngine.GameManager.discard(socket.assigns.game_id, user_name, idx)
    {:noreply, socket}
  end

  def handle_in("play", %{"userName" => user_name, "idx" => idx}, socket) do
    HanabiEngine.GameManager.play(socket.assigns.game_id, user_name, idx)
    {:noreply, socket}
  end

  def handle_info({:game_started, game_id}, socket) do
    HanabiEngine.GameManager.subscribe(game_id)
    socket = socket |> assign(:game_id, game_id)
    {:noreply, socket}
  end

  def handle_info({:game_start_error, message, player_name}, socket) do
    push(socket, "game_start_error", %{success: false, message: message, userName: player_name})
    {:noreply, socket}
  end

  def handle_info({:deal, :ok, game}, socket) do
    push(socket, "game", HanabiEngine.Game.to_player_view(game, socket.assigns.user_name))
    {:noreply, socket}
  end

  def handle_info({{:discard, _user_name, _idx}, :ok, game}, socket) do
    push(socket, "game", HanabiEngine.Game.to_player_view(game, socket.assigns.user_name))
    {:noreply, socket}
  end

  def handle_info({{:play, _user_name, _idx}, :ok, game}, socket) do
    push(socket, "game", HanabiEngine.Game.to_player_view(game, socket.assigns.user_name))
    {:noreply, socket}
  end

  defp start_game(players) do
    result = HanabiEngine.GameManager.start_new(Map.keys(players))
    case result do
      {:ok, game_id, _player_names, _seed} ->
        players
        |> Enum.each(fn {_player_name, pid} -> send(pid, {:game_started, game_id}) end)
        HanabiEngine.GameManager.deal(game_id)

      {:error, message} ->
        players
        |> Enum.each(fn {player_name, pid} -> send(pid, {:game_start_error, message, player_name}) end)
    end
  end

end

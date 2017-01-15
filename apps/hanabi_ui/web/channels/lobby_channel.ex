defmodule HanabiUi.LobbyChannel do
  use Phoenix.Channel
  require Logger

  def join("game:lobby", _message, socket), do: {:ok, socket}
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
    {result, new_socket} =
      case HanabiEngine.MatchMaker.join_game(user_name, player_count) do
        {:ready, players} ->
          start_game(players)
          {
            succeed(user_name, "You are waiting for a game."),
            assign(socket, :player_acknowledgements, player_count)
          }
        {:waiting, _players} ->
          {succeed(user_name, "You are waiting for a game."), socket}
        {:error, message} ->
          {{:ok, fail(user_name, message)}, socket}
      end
    {:reply, result, new_socket}
  end

  def handle_info({:game_started, game_id, pid}, socket) do
    Phoenix.PubSub.broadcast!(
      :players,
      "player:#{socket.assigns.uuid}",
      {
        :game_started,
        socket.assigns.uuid,
        socket.assigns.user_name,
        game_id,
        pid
      }
    )
    new_socket = assign(socket, :game_id, game_id)
    {:noreply, new_socket}
  end
  def handle_info(:player_acknowledgement, socket) do
    new_socket =
      if socket.assigns.player_acknowledgements == 1 do
        HanabiEngine.GameManager.deal(socket.assigns.game_id)
        socket
      else
        assign(
          socket,
          :player_acknowledgements,
          socket.assigns.player_acknowledgements - 1
        )
      end
    {:noreply, new_socket}
  end
  def handle_info({:game_start_error, message, player_name}, socket) do
    push(socket, "game_start_error", fail(player_name, message))
    {:noreply, socket}
  end
  def handle_info(message, socket) do
    Logger.debug "Unexpected message:  #{inspect message}"
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
    sorted_names =
      players
      |> Map.keys
      |> Enum.sort
    case HanabiStorage.most_recent_game_event_for(sorted_names) do
      saved_game = %HanabiStorage.Game{event: "started"} ->
        result =
          HanabiEngine.GameManager.start(
            saved_game.uuid,
            sorted_names,
            saved_game.seed,
            &HanabiStorage.load/1
          )
        case result do
          success when is_tuple(success) and elem(success, 0) == :ok ->
            HanabiStorage.Recorder.record_game(saved_game.uuid)
            notify_players_of_game(players, saved_game.uuid)
          {:error, message} ->
            notify_players_of_game_error(players, message)
        end
      _ ->
        result =
          HanabiEngine.GameManager.start_new(
            sorted_names,
            &HanabiStorage.load/1
          )
        case result do
          {:ok, game_id, _player_names, seed} ->
            HanabiStorage.Recorder.start_game(game_id, sorted_names, seed)
            notify_players_of_game(players, game_id)
          {:error, message} ->
            notify_players_of_game_error(players, message)
        end
    end
  end

  defp notify_players_of_game(players, game_id) do
    Enum.each(players, fn {_player_name, pid} ->
      send(pid, {:game_started, game_id, self()})
    end)
  end

  defp notify_players_of_game_error(players, message) do
    Enum.each(players, fn {player_name, pid} ->
      send(pid, {:game_start_error, message, player_name})
    end)
  end
end

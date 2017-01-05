defmodule HanabiEngine.MatchMaker do
  @moduledoc ~S"""
  This module provides user and game registration services.
  """

  use GenServer
  require Logger

  ### Client ###

  @doc ~S"""
  Starts the one and only `MatchMaker` service.
  """
  def start_link do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @doc ~S"""
  Registers a user process by name.
  """
  def register(user_name) do
    GenServer.call(__MODULE__, {:register, user_name, self})
  end

  @doc ~S"""
  Looks up the PID for a user process by name.
  """
  def user(user_name) do
    case :ets.lookup(:users, user_name) do
      [{^user_name, pid}] -> pid
      [ ] -> nil
      _ -> raise "Unexpected lookup result"
    end
  end

  @doc ~S"""
  Joins a game under the passed user name for `player_count` players.  This
  function returns all current players mapped to their respective PID's.
  """
  def join_game(_user_name, player_count)
  when not (is_integer(player_count) and player_count in 2..5) do
    {:error, "Invalid player count."}
  end
  def join_game(user_name, player_count) do
    if user(user_name) == self do
      GenServer.call(__MODULE__, {:join_game, user_name, player_count})
    else
      {:error, "You can only add your user to games."}
    end
  end

  ### Server ###

  @doc false
  def init(nil) do
    :ets.new(:users, [:set, :protected, :named_table])
    :ets.new(:games, [:set, :protected, :named_table])
    {:ok, nil}
  end

  @doc false
  def handle_call({:register, user_name, pid}, _from, nil) do
    if :ets.insert_new(:users, {user_name, pid}) do
      Process.monitor(pid)
      {:reply, :ok, nil}
    else
      {:reply, {:error, "User name unavailable."}, nil}
    end
  end

  @doc false
  def handle_call({:join_game, user_name, player_count}, _from, nil) do
    case :ets.match(:games, {player_count, :"$1"}) do
      [[players]] when is_list(players) ->
        unless Enum.any?(players, fn player -> player == user_name end) do
          :ets.insert(:games, {player_count, [user_name | players]})
        end
      [ ] ->
        :ets.insert(:games, {player_count, [user_name]})
      _ ->
        raise "Unexpected game match."
    end
    players = players_for_game(player_count)
    reply =
      if map_size(players) == player_count do
        :ets.delete(:games, player_count)
        {:ready, players}
      else
        {:waiting, players}
      end
    {:reply, reply, nil}
  end

  @doc false
  def handle_info({:DOWN, _ref, :process, pid, _reason}, nil) do
    case :ets.match_object(:users, {:_, pid}) do
      [{user_name, ^pid}] ->
        :ets.delete(:users, user_name)
        :ets.select(:games, users_games_query(user_name))
        |> Enum.each(fn {player_count, players} ->
          :ets.insert(:games, {player_count, List.delete(players, user_name)})
        end)
      _ ->
        raise "Unexpected match for removal."
    end
    {:noreply, nil}
  end
  def handle_info(message, nil) do
    Logger.debug "Unexpected message:  #{inspect message}"
    {:noreply, nil}
  end

  ### Helpers ###

  defp players_for_game(player_count) do
    :ets.lookup(:games, player_count)
    |> hd
    |> elem(1)
    |> Enum.map(fn user_name -> {user_name, user(user_name)} end)
    |> Enum.into(%{ })
  end

  defp users_games_query(user_name) do
    match_players = {:_, :"$2"}
    user_in_players =
      {:orelse,
        {:orelse,
          {:orelse,
            {:orelse,
              {:andalso,
                {:>=, {:length, :"$2"}, 1},
                {:==, {:hd, :"$2"}, user_name}
              },
              {:andalso,
                {:>=, {:length, :"$2"}, 2},
                {:==, {:hd, {:hd, :"$2"}}, user_name}
              }
            },
            {:andalso,
              {:>=, {:length, :"$2"}, 3},
              {:==, {:hd, {:hd, {:hd, :"$2"}}}, user_name}
            }
          },
          {:andalso,
            {:>=, {:length, :"$2"}, 4},
            {:==, {:hd, {:hd, {:hd, {:hd, :"$2"}}}}, user_name}
          }
        },
        {:andalso,
          {:>=, {:length, :"$2"}, 5},
          {:==, {:hd, {:hd, {:hd, {:hd, {:hd, :"$2"}}}}}, user_name}
        }
      }
    return_full_entry = :"$_"
    [{match_players, [user_in_players], [return_full_entry]}]
  end
end

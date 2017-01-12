defmodule HanabiStorage.Move do
  use Ecto.Schema
  import Ecto.Changeset

  schema "moves" do
    belongs_to :game, HanabiStorage.Game, type: Ecto.UUID

    field :play, :string
    field :arguments, :binary
    field :inserted_at, :utc_datetime
  end

  def changeset(game_id, play, arguments) do
    normalized_params =
      %{
        game_id: game_id,
        play: play,
        arguments: :erlang.term_to_binary(arguments),
        inserted_at: DateTime.utc_now
      }
    %__MODULE__{ }
    |> cast(normalized_params, Map.keys(normalized_params))
    |> validate_inclusion(:play, ~w[hint discard play])
  end
end

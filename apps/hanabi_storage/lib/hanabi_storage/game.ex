defmodule HanabiStorage.Game do
  use Ecto.Schema
  import Ecto.Changeset
  alias HanabiStorage.SerializedField

  schema "games" do
    field :uuid, Ecto.UUID
    field :event, :string
    field :players, {:array, :string}
    field :seed, SerializedField
    field :inserted_at, :utc_datetime

    has_many :moves, HanabiStorage.Move, foreign_key: :game_id, references: :uuid
  end

  def started_changeset(game_id, players, seed) do
    normalized_params =
      %{
        uuid: game_id,
        event: "started",
        players: players,
        seed: seed,
        inserted_at: DateTime.utc_now
      }
    %__MODULE__{ }
    |> cast(normalized_params, Map.keys(normalized_params))
    |> validate_inclusion(:event, ~w[started finished])
  end
end

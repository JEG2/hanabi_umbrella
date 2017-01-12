defmodule HanabiStorage.Game do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, [ ]}
  schema "games" do
    field :event, :string
    field :players, {:array, :string}
    field :seed, :binary
  end

  def start_changeset(id, players, seed) do
    normalized_params =
      %{
        id: id,
        event: "started",
        players: Enum.sort(players),
        seed: :erlang.term_to_binary(seed)
      }
    %__MODULE__{ }
    |> cast(normalized_params, Map.keys(normalized_params))
    |> validate_inclusion(:event, ~w[started finished])
  end
end

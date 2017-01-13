defmodule HanabiStorage.Repo.Migrations.CreateGames do
  use Ecto.Migration

  def change do
    create table(:games) do
      add :uuid, :uuid
      add :event, :string
      add :players, {:array, :string}
      add :seed, :binary
      add :inserted_at, :utc_datetime
    end
    create index(:games, ~w[players inserted_at]a)
  end
end

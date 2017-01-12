defmodule HanabiStorage.Repo.Migrations.CreateGames do
  use Ecto.Migration

  def change do
    create table(:games, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :event, :string
      add :players, {:array, :string}
      add :seed, :binary
      add :created_at, :utc_datetime
    end
  end
end

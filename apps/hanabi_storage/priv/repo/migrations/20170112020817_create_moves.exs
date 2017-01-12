defmodule HanabiStorage.Repo.Migrations.CreateMoves do
  use Ecto.Migration

  def change do
    create table(:moves) do
      add :game_id, :uuid
      add :play, :string
      add :arguments, :binary
      add :inserted_at, :utc_datetime
    end
    create index(:moves, :play)
  end
end

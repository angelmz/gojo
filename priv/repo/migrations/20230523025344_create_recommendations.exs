defmodule Gojo.Repo.Migrations.CreateRecommendations do
  use Ecto.Migration

  def change do
    create table(:recommendations) do
      add :rating, :float

      timestamps()
    end
  end
end

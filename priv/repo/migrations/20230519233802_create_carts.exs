defmodule Gojo.Repo.Migrations.CreateCarts do
  use Ecto.Migration

  def change do
    create table(:carts) do
      add :user_id, references(:users, on_delete: :nothing)

      timestamps()
    end

    create unique_index(:carts, [:user_id])
  end
end

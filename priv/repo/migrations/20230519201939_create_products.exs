defmodule Gojo.Repo.Migrations.CreateProducts do
  use Ecto.Migration

  def change do
    create table(:products) do
      add :title, :string
      add :description, :string
      add :price, :decimal, precision: 15, scale: 6, null: false
      add :sku, :bigint, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      # quantity, image url, category, manufacturer.

      timestamps()
    end

    create unique_index(:products, [:sku, :user_id])
  end
end

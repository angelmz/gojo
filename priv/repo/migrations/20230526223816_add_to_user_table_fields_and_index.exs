defmodule Gojo.Repo.Migrations.AddToUserTableFieldsAndIndex do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :name, :string, null: false
    end

    drop index(:users, [:email])
    create unique_index(:users, [:email, :tenant_id])
  end

  def down do
    alter table(:users) do
      remove :name
    end

    drop index(:users, [:email, :tenant_id])
    create unique_index(:users, [:email])
  end
end

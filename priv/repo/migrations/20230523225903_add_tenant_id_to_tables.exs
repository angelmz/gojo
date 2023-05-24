defmodule Gojo.Repo.Migrations.AddTenantIdToTables do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
    end
  end

  def down do
    alter table(:users) do
      remove :tenant_id
    end
  end
end

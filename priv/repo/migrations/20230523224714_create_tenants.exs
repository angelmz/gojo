defmodule Gojo.Repo.Migrations.CreateTenantsAuthTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:tenants) do
      add :name, :string
      add :subdomain, :string
      add :email, :citext, null: false
      add :hashed_password, :string, null: false
      add :confirmed_at, :naive_datetime
      timestamps()
    end

    create unique_index(:tenants, [:email, :subdomain])

    create table(:tenants_tokens) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(updated_at: false)
    end

    create index(:tenants_tokens, [:tenant_id])
    create unique_index(:tenants_tokens, [:context, :token])
  end
end

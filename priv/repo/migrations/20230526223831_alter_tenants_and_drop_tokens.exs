defmodule Gojo.Repo.Migrations.AlterTenantsAndDropTokens do
  use Ecto.Migration

  def up do
    drop index(:tenants, [:email, :subdomain])

    alter table(:tenants) do
      remove :email
      remove :hashed_password
      remove :confirmed_at
      add :domain, :string
    end

    drop table(:tenants_tokens)

    create unique_index(:tenants, [:subdomain])
  end

  def down do
    drop index(:tenants, [:subdomain])

    alter table(:tenants) do
      add :email, :citext, null: false
      add :hashed_password, :string, null: false
      add :confirmed_at, :naive_datetime
      remove :domain
    end

    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:tenants_tokens) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(updated_at: false)
    end

    create index(:tenants_tokens, [:tenant_id])
    create unique_index(:tenants_tokens, [:context, :token])

    create unique_index(:tenants, [:email, :subdomain])
  end
end

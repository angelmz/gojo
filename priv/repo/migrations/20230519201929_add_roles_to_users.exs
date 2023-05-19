defmodule Gojo.Repo.Migrations.AddRoleToUsers do
  use Ecto.Migration
  alias Gojo.Accounts.User.RolesEnum

  def up do
    RolesEnum.create_type()

    alter table(:users) do
      add :role, RolesEnum.type(), null: false
    end
  end

  def down do
    alter table(:users) do
      remove :role
    end

    RolesEnum.drop_type()
  end
end

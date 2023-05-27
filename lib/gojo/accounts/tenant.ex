defmodule Gojo.Accounts.Tenant do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tenants" do
    field :domain, :string
    field :name, :string
    field :subdomain, :string

    has_many :users, Gojo.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(tenant, attrs) do
    tenant
    |> cast(attrs, [:name, :subdomain, :domain])
    |> validate_required([:name, :subdomain, :domain])
    |> unique_constraint(:subdomain)
  end
end

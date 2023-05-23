defmodule Gojo.Tenants do
  alias Gojo.Repo

  def register_tenant(tenant_name) do
    try do
      create_tenant_schema(tenant_name)
      {:ok, tenant_name}
    rescue
      e in Ecto.MigrationError ->
        {:error, e}
    end
  end

  def list_tenant_ids() do
    Repo.query("SELECT schema_name FROM information_schema.schemata")
    |> Enum.map(fn row -> row.schema_name end)
    |> Enum.filter(fn schema_name -> schema_name != "public" end)
  end

  defp create_tenant_schema(tenant_name) do
    Repo.query("CREATE SCHEMA IF NOT EXISTS #{tenant_name}")
  end
end

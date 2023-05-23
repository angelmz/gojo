defmodule Mix.Tasks.Gojo.MigrateTenants do
  use Mix.Task
  import Mix.Ecto

  def run(_) do
    tenant_ids = Gojo.Tenants.list_tenant_ids() # You need to implement this function
    for tenant_id <- tenant_ids do
      Application.put_env(:gojo, :tenant_id, tenant_id)
      Mix.Task.run("ecto.migrate", ["-r", "Gojo.TenantRepo"])
    end
  end
end

defmodule Gojo.TenantRepo do
  use Ecto.Repo,
    otp_app: :gojo,
    adapter: Ecto.Adapters.Postgres

  def default_options(opts \\ []) do
    [schema: tenant_schema()] ++ opts
  end

  defp tenant_schema do
    # Assumes you have a way to get current tenant_id from the request
    :gojo
    |> Application.get_env(:tenant_id)
    |> to_string()
  end
end

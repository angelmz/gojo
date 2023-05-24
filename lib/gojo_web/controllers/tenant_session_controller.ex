defmodule GojoWeb.TenantSessionController do
  use GojoWeb, :controller

  alias Gojo.Accounts
  alias GojoWeb.TenantAuth

  def create(conn, %{"_action" => "registered"} = params) do
    create(conn, params, "Account created successfully!")
  end

  def create(conn, %{"_action" => "password_updated"} = params) do
    conn
    |> put_session(:tenant_return_to, ~p"/tenants/settings")
    |> create(params, "Password updated successfully!")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  defp create(conn, %{"tenant" => tenant_params}, info) do
    %{"email" => email, "password" => password} = tenant_params

    if tenant = Accounts.get_tenant_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, info)
      |> TenantAuth.log_in_tenant(tenant, tenant_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid email or password")
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"/tenants/log_in")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> TenantAuth.log_out_tenant()
  end
end

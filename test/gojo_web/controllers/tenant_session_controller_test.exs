defmodule GojoWeb.TenantSessionControllerTest do
  use GojoWeb.ConnCase, async: true

  import Gojo.AccountsFixtures

  setup do
    %{tenant: tenant_fixture()}
  end

  describe "POST /tenants/log_in" do
    test "logs the tenant in", %{conn: conn, tenant: tenant} do
      conn =
        post(conn, ~p"/tenants/log_in", %{
          "tenant" => %{"email" => tenant.email, "password" => valid_tenant_password()}
        })

      assert get_session(conn, :tenant_token)
      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ tenant.email
      assert response =~ ~p"/tenants/settings"
      assert response =~ ~p"/tenants/log_out"
    end

    test "logs the tenant in with remember me", %{conn: conn, tenant: tenant} do
      conn =
        post(conn, ~p"/tenants/log_in", %{
          "tenant" => %{
            "email" => tenant.email,
            "password" => valid_tenant_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_gojo_web_tenant_remember_me"]
      assert redirected_to(conn) == ~p"/"
    end

    test "logs the tenant in with return to", %{conn: conn, tenant: tenant} do
      conn =
        conn
        |> init_test_session(tenant_return_to: "/foo/bar")
        |> post(~p"/tenants/log_in", %{
          "tenant" => %{
            "email" => tenant.email,
            "password" => valid_tenant_password()
          }
        })

      assert redirected_to(conn) == "/foo/bar"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Welcome back!"
    end

    test "login following registration", %{conn: conn, tenant: tenant} do
      conn =
        conn
        |> post(~p"/tenants/log_in", %{
          "_action" => "registered",
          "tenant" => %{
            "email" => tenant.email,
            "password" => valid_tenant_password()
          }
        })

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Account created successfully"
    end

    test "login following password update", %{conn: conn, tenant: tenant} do
      conn =
        conn
        |> post(~p"/tenants/log_in", %{
          "_action" => "password_updated",
          "tenant" => %{
            "email" => tenant.email,
            "password" => valid_tenant_password()
          }
        })

      assert redirected_to(conn) == ~p"/tenants/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Password updated successfully"
    end

    test "redirects to login page with invalid credentials", %{conn: conn} do
      conn =
        post(conn, ~p"/tenants/log_in", %{
          "tenant" => %{"email" => "invalid@email.com", "password" => "invalid_password"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
      assert redirected_to(conn) == ~p"/tenants/log_in"
    end
  end

  describe "DELETE /tenants/log_out" do
    test "logs the tenant out", %{conn: conn, tenant: tenant} do
      conn = conn |> log_in_tenant(tenant) |> delete(~p"/tenants/log_out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :tenant_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the tenant is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/tenants/log_out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :tenant_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end
  end
end

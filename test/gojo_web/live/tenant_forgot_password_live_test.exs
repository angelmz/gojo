defmodule GojoWeb.TenantForgotPasswordLiveTest do
  use GojoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Gojo.AccountsFixtures

  alias Gojo.Accounts
  alias Gojo.Repo

  describe "Forgot password page" do
    test "renders email page", %{conn: conn} do
      {:ok, lv, html} = live(conn, ~p"/tenants/reset_password")

      assert html =~ "Forgot your password?"
      assert has_element?(lv, ~s|a[href="#{~p"/tenants/register"}"]|, "Register")
      assert has_element?(lv, ~s|a[href="#{~p"/tenants/log_in"}"]|, "Log in")
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_tenant(tenant_fixture())
        |> live(~p"/tenants/reset_password")
        |> follow_redirect(conn, ~p"/")

      assert {:ok, _conn} = result
    end
  end

  describe "Reset link" do
    setup do
      %{tenant: tenant_fixture()}
    end

    test "sends a new reset password token", %{conn: conn, tenant: tenant} do
      {:ok, lv, _html} = live(conn, ~p"/tenants/reset_password")

      {:ok, conn} =
        lv
        |> form("#reset_password_form", tenant: %{"email" => tenant.email})
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "If your email is in our system"

      assert Repo.get_by!(Accounts.TenantToken, tenant_id: tenant.id).context ==
               "reset_password"
    end

    test "does not send reset password token if email is invalid", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/tenants/reset_password")

      {:ok, conn} =
        lv
        |> form("#reset_password_form", tenant: %{"email" => "unknown@example.com"})
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "If your email is in our system"
      assert Repo.all(Accounts.TenantToken) == []
    end
  end
end

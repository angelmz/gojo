defmodule GojoWeb.TenantConfirmationLiveTest do
  use GojoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Gojo.AccountsFixtures

  alias Gojo.Accounts
  alias Gojo.Repo

  setup do
    %{tenant: tenant_fixture()}
  end

  describe "Confirm tenant" do
    test "renders confirmation page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/tenants/confirm/some-token")
      assert html =~ "Confirm Account"
    end

    test "confirms the given token once", %{conn: conn, tenant: tenant} do
      token =
        extract_tenant_token(fn url ->
          Accounts.deliver_tenant_confirmation_instructions(tenant, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"/tenants/confirm/#{token}")

      result =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert {:ok, conn} = result

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Tenant confirmed successfully"

      assert Accounts.get_tenant!(tenant.id).confirmed_at
      refute get_session(conn, :tenant_token)
      assert Repo.all(Accounts.TenantToken) == []

      # when not logged in
      {:ok, lv, _html} = live(conn, ~p"/tenants/confirm/#{token}")

      result =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert {:ok, conn} = result

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Tenant confirmation link is invalid or it has expired"

      # when logged in
      {:ok, lv, _html} =
        build_conn()
        |> log_in_tenant(tenant)
        |> live(~p"/tenants/confirm/#{token}")

      result =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert {:ok, conn} = result
      refute Phoenix.Flash.get(conn.assigns.flash, :error)
    end

    test "does not confirm email with invalid token", %{conn: conn, tenant: tenant} do
      {:ok, lv, _html} = live(conn, ~p"/tenants/confirm/invalid-token")

      {:ok, conn} =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Tenant confirmation link is invalid or it has expired"

      refute Accounts.get_tenant!(tenant.id).confirmed_at
    end
  end
end

defmodule GojoWeb.TenantConfirmationInstructionsLiveTest do
  use GojoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Gojo.AccountsFixtures

  alias Gojo.Accounts
  alias Gojo.Repo

  setup do
    %{tenant: tenant_fixture()}
  end

  describe "Resend confirmation" do
    test "renders the resend confirmation page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/tenants/confirm")
      assert html =~ "Resend confirmation instructions"
    end

    test "sends a new confirmation token", %{conn: conn, tenant: tenant} do
      {:ok, lv, _html} = live(conn, ~p"/tenants/confirm")

      {:ok, conn} =
        lv
        |> form("#resend_confirmation_form", tenant: %{email: tenant.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.get_by!(Accounts.TenantToken, tenant_id: tenant.id).context == "confirm"
    end

    test "does not send confirmation token if tenant is confirmed", %{conn: conn, tenant: tenant} do
      Repo.update!(Accounts.Tenant.confirm_changeset(tenant))

      {:ok, lv, _html} = live(conn, ~p"/tenants/confirm")

      {:ok, conn} =
        lv
        |> form("#resend_confirmation_form", tenant: %{email: tenant.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      refute Repo.get_by(Accounts.TenantToken, tenant_id: tenant.id)
    end

    test "does not send confirmation token if email is invalid", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/tenants/confirm")

      {:ok, conn} =
        lv
        |> form("#resend_confirmation_form", tenant: %{email: "unknown@example.com"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.all(Accounts.TenantToken) == []
    end
  end
end

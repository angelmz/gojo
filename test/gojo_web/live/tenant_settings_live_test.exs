defmodule GojoWeb.TenantSettingsLiveTest do
  use GojoWeb.ConnCase

  alias Gojo.Accounts
  import Phoenix.LiveViewTest
  import Gojo.AccountsFixtures

  describe "Settings page" do
    test "renders settings page", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_tenant(tenant_fixture())
        |> live(~p"/tenants/settings")

      assert html =~ "Change Email"
      assert html =~ "Change Password"
    end

    test "redirects if tenant is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/tenants/settings")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/tenants/log_in"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end

  describe "update email form" do
    setup %{conn: conn} do
      password = valid_tenant_password()
      tenant = tenant_fixture(%{password: password})
      %{conn: log_in_tenant(conn, tenant), tenant: tenant, password: password}
    end

    test "updates the tenant email", %{conn: conn, password: password, tenant: tenant} do
      new_email = unique_tenant_email()

      {:ok, lv, _html} = live(conn, ~p"/tenants/settings")

      result =
        lv
        |> form("#email_form", %{
          "current_password" => password,
          "tenant" => %{"email" => new_email}
        })
        |> render_submit()

      assert result =~ "A link to confirm your email"
      assert Accounts.get_tenant_by_email(tenant.email)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/tenants/settings")

      result =
        lv
        |> element("#email_form")
        |> render_change(%{
          "action" => "update_email",
          "current_password" => "invalid",
          "tenant" => %{"email" => "with spaces"}
        })

      assert result =~ "Change Email"
      assert result =~ "must have the @ sign and no spaces"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn, tenant: tenant} do
      {:ok, lv, _html} = live(conn, ~p"/tenants/settings")

      result =
        lv
        |> form("#email_form", %{
          "current_password" => "invalid",
          "tenant" => %{"email" => tenant.email}
        })
        |> render_submit()

      assert result =~ "Change Email"
      assert result =~ "did not change"
      assert result =~ "is not valid"
    end
  end

  describe "update password form" do
    setup %{conn: conn} do
      password = valid_tenant_password()
      tenant = tenant_fixture(%{password: password})
      %{conn: log_in_tenant(conn, tenant), tenant: tenant, password: password}
    end

    test "updates the tenant password", %{conn: conn, tenant: tenant, password: password} do
      new_password = valid_tenant_password()

      {:ok, lv, _html} = live(conn, ~p"/tenants/settings")

      form =
        form(lv, "#password_form", %{
          "current_password" => password,
          "tenant" => %{
            "email" => tenant.email,
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })

      render_submit(form)

      new_password_conn = follow_trigger_action(form, conn)

      assert redirected_to(new_password_conn) == ~p"/tenants/settings"

      assert get_session(new_password_conn, :tenant_token) != get_session(conn, :tenant_token)

      assert Phoenix.Flash.get(new_password_conn.assigns.flash, :info) =~
               "Password updated successfully"

      assert Accounts.get_tenant_by_email_and_password(tenant.email, new_password)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/tenants/settings")

      result =
        lv
        |> element("#password_form")
        |> render_change(%{
          "current_password" => "invalid",
          "tenant" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      assert result =~ "Change Password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/tenants/settings")

      result =
        lv
        |> form("#password_form", %{
          "current_password" => "invalid",
          "tenant" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })
        |> render_submit()

      assert result =~ "Change Password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
      assert result =~ "is not valid"
    end
  end

  describe "confirm email" do
    setup %{conn: conn} do
      tenant = tenant_fixture()
      email = unique_tenant_email()

      token =
        extract_tenant_token(fn url ->
          Accounts.deliver_tenant_update_email_instructions(%{tenant | email: email}, tenant.email, url)
        end)

      %{conn: log_in_tenant(conn, tenant), token: token, email: email, tenant: tenant}
    end

    test "updates the tenant email once", %{conn: conn, tenant: tenant, token: token, email: email} do
      {:error, redirect} = live(conn, ~p"/tenants/settings/confirm_email/#{token}")

      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/tenants/settings"
      assert %{"info" => message} = flash
      assert message == "Email changed successfully."
      refute Accounts.get_tenant_by_email(tenant.email)
      assert Accounts.get_tenant_by_email(email)

      # use confirm token again
      {:error, redirect} = live(conn, ~p"/tenants/settings/confirm_email/#{token}")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/tenants/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
    end

    test "does not update email with invalid token", %{conn: conn, tenant: tenant} do
      {:error, redirect} = live(conn, ~p"/tenants/settings/confirm_email/oops")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/tenants/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
      assert Accounts.get_tenant_by_email(tenant.email)
    end

    test "redirects if tenant is not logged in", %{token: token} do
      conn = build_conn()
      {:error, redirect} = live(conn, ~p"/tenants/settings/confirm_email/#{token}")
      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/tenants/log_in"
      assert %{"error" => message} = flash
      assert message == "You must log in to access this page."
    end
  end
end

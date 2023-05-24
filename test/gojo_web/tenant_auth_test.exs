defmodule GojoWeb.TenantAuthTest do
  use GojoWeb.ConnCase, async: true

  alias Phoenix.LiveView
  alias Gojo.Accounts
  alias GojoWeb.TenantAuth
  import Gojo.AccountsFixtures

  @remember_me_cookie "_gojo_web_tenant_remember_me"

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, GojoWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{tenant: tenant_fixture(), conn: conn}
  end

  describe "log_in_tenant/3" do
    test "stores the tenant token in the session", %{conn: conn, tenant: tenant} do
      conn = TenantAuth.log_in_tenant(conn, tenant)
      assert token = get_session(conn, :tenant_token)
      assert get_session(conn, :live_socket_id) == "tenants_sessions:#{Base.url_encode64(token)}"
      assert redirected_to(conn) == ~p"/"
      assert Accounts.get_tenant_by_session_token(token)
    end

    test "clears everything previously stored in the session", %{conn: conn, tenant: tenant} do
      conn = conn |> put_session(:to_be_removed, "value") |> TenantAuth.log_in_tenant(tenant)
      refute get_session(conn, :to_be_removed)
    end

    test "redirects to the configured path", %{conn: conn, tenant: tenant} do
      conn = conn |> put_session(:tenant_return_to, "/hello") |> TenantAuth.log_in_tenant(tenant)
      assert redirected_to(conn) == "/hello"
    end

    test "writes a cookie if remember_me is configured", %{conn: conn, tenant: tenant} do
      conn = conn |> fetch_cookies() |> TenantAuth.log_in_tenant(tenant, %{"remember_me" => "true"})
      assert get_session(conn, :tenant_token) == conn.cookies[@remember_me_cookie]

      assert %{value: signed_token, max_age: max_age} = conn.resp_cookies[@remember_me_cookie]
      assert signed_token != get_session(conn, :tenant_token)
      assert max_age == 5_184_000
    end
  end

  describe "logout_tenant/1" do
    test "erases session and cookies", %{conn: conn, tenant: tenant} do
      tenant_token = Accounts.generate_tenant_session_token(tenant)

      conn =
        conn
        |> put_session(:tenant_token, tenant_token)
        |> put_req_cookie(@remember_me_cookie, tenant_token)
        |> fetch_cookies()
        |> TenantAuth.log_out_tenant()

      refute get_session(conn, :tenant_token)
      refute conn.cookies[@remember_me_cookie]
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == ~p"/"
      refute Accounts.get_tenant_by_session_token(tenant_token)
    end

    test "broadcasts to the given live_socket_id", %{conn: conn} do
      live_socket_id = "tenants_sessions:abcdef-token"
      GojoWeb.Endpoint.subscribe(live_socket_id)

      conn
      |> put_session(:live_socket_id, live_socket_id)
      |> TenantAuth.log_out_tenant()

      assert_receive %Phoenix.Socket.Broadcast{event: "disconnect", topic: ^live_socket_id}
    end

    test "works even if tenant is already logged out", %{conn: conn} do
      conn = conn |> fetch_cookies() |> TenantAuth.log_out_tenant()
      refute get_session(conn, :tenant_token)
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "fetch_current_tenant/2" do
    test "authenticates tenant from session", %{conn: conn, tenant: tenant} do
      tenant_token = Accounts.generate_tenant_session_token(tenant)
      conn = conn |> put_session(:tenant_token, tenant_token) |> TenantAuth.fetch_current_tenant([])
      assert conn.assigns.current_tenant.id == tenant.id
    end

    test "authenticates tenant from cookies", %{conn: conn, tenant: tenant} do
      logged_in_conn =
        conn |> fetch_cookies() |> TenantAuth.log_in_tenant(tenant, %{"remember_me" => "true"})

      tenant_token = logged_in_conn.cookies[@remember_me_cookie]
      %{value: signed_token} = logged_in_conn.resp_cookies[@remember_me_cookie]

      conn =
        conn
        |> put_req_cookie(@remember_me_cookie, signed_token)
        |> TenantAuth.fetch_current_tenant([])

      assert conn.assigns.current_tenant.id == tenant.id
      assert get_session(conn, :tenant_token) == tenant_token

      assert get_session(conn, :live_socket_id) ==
               "tenants_sessions:#{Base.url_encode64(tenant_token)}"
    end

    test "does not authenticate if data is missing", %{conn: conn, tenant: tenant} do
      _ = Accounts.generate_tenant_session_token(tenant)
      conn = TenantAuth.fetch_current_tenant(conn, [])
      refute get_session(conn, :tenant_token)
      refute conn.assigns.current_tenant
    end
  end

  describe "on_mount: mount_current_tenant" do
    test "assigns current_tenant based on a valid tenant_token ", %{conn: conn, tenant: tenant} do
      tenant_token = Accounts.generate_tenant_session_token(tenant)
      session = conn |> put_session(:tenant_token, tenant_token) |> get_session()

      {:cont, updated_socket} =
        TenantAuth.on_mount(:mount_current_tenant, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_tenant.id == tenant.id
    end

    test "assigns nil to current_tenant assign if there isn't a valid tenant_token ", %{conn: conn} do
      tenant_token = "invalid_token"
      session = conn |> put_session(:tenant_token, tenant_token) |> get_session()

      {:cont, updated_socket} =
        TenantAuth.on_mount(:mount_current_tenant, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_tenant == nil
    end

    test "assigns nil to current_tenant assign if there isn't a tenant_token", %{conn: conn} do
      session = conn |> get_session()

      {:cont, updated_socket} =
        TenantAuth.on_mount(:mount_current_tenant, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_tenant == nil
    end
  end

  describe "on_mount: ensure_authenticated" do
    test "authenticates current_tenant based on a valid tenant_token ", %{conn: conn, tenant: tenant} do
      tenant_token = Accounts.generate_tenant_session_token(tenant)
      session = conn |> put_session(:tenant_token, tenant_token) |> get_session()

      {:cont, updated_socket} =
        TenantAuth.on_mount(:ensure_authenticated, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_tenant.id == tenant.id
    end

    test "redirects to login page if there isn't a valid tenant_token ", %{conn: conn} do
      tenant_token = "invalid_token"
      session = conn |> put_session(:tenant_token, tenant_token) |> get_session()

      socket = %LiveView.Socket{
        endpoint: GojoWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} = TenantAuth.on_mount(:ensure_authenticated, %{}, session, socket)
      assert updated_socket.assigns.current_tenant == nil
    end

    test "redirects to login page if there isn't a tenant_token ", %{conn: conn} do
      session = conn |> get_session()

      socket = %LiveView.Socket{
        endpoint: GojoWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} = TenantAuth.on_mount(:ensure_authenticated, %{}, session, socket)
      assert updated_socket.assigns.current_tenant == nil
    end
  end

  describe "on_mount: :redirect_if_tenant_is_authenticated" do
    test "redirects if there is an authenticated  tenant ", %{conn: conn, tenant: tenant} do
      tenant_token = Accounts.generate_tenant_session_token(tenant)
      session = conn |> put_session(:tenant_token, tenant_token) |> get_session()

      assert {:halt, _updated_socket} =
               TenantAuth.on_mount(
                 :redirect_if_tenant_is_authenticated,
                 %{},
                 session,
                 %LiveView.Socket{}
               )
    end

    test "Don't redirect is there is no authenticated tenant", %{conn: conn} do
      session = conn |> get_session()

      assert {:cont, _updated_socket} =
               TenantAuth.on_mount(
                 :redirect_if_tenant_is_authenticated,
                 %{},
                 session,
                 %LiveView.Socket{}
               )
    end
  end

  describe "redirect_if_tenant_is_authenticated/2" do
    test "redirects if tenant is authenticated", %{conn: conn, tenant: tenant} do
      conn = conn |> assign(:current_tenant, tenant) |> TenantAuth.redirect_if_tenant_is_authenticated([])
      assert conn.halted
      assert redirected_to(conn) == ~p"/"
    end

    test "does not redirect if tenant is not authenticated", %{conn: conn} do
      conn = TenantAuth.redirect_if_tenant_is_authenticated(conn, [])
      refute conn.halted
      refute conn.status
    end
  end

  describe "require_authenticated_tenant/2" do
    test "redirects if tenant is not authenticated", %{conn: conn} do
      conn = conn |> fetch_flash() |> TenantAuth.require_authenticated_tenant([])
      assert conn.halted

      assert redirected_to(conn) == ~p"/tenants/log_in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "stores the path to redirect to on GET", %{conn: conn} do
      halted_conn =
        %{conn | path_info: ["foo"], query_string: ""}
        |> fetch_flash()
        |> TenantAuth.require_authenticated_tenant([])

      assert halted_conn.halted
      assert get_session(halted_conn, :tenant_return_to) == "/foo"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar=baz"}
        |> fetch_flash()
        |> TenantAuth.require_authenticated_tenant([])

      assert halted_conn.halted
      assert get_session(halted_conn, :tenant_return_to) == "/foo?bar=baz"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar", method: "POST"}
        |> fetch_flash()
        |> TenantAuth.require_authenticated_tenant([])

      assert halted_conn.halted
      refute get_session(halted_conn, :tenant_return_to)
    end

    test "does not redirect if tenant is authenticated", %{conn: conn, tenant: tenant} do
      conn = conn |> assign(:current_tenant, tenant) |> TenantAuth.require_authenticated_tenant([])
      refute conn.halted
      refute conn.status
    end
  end
end

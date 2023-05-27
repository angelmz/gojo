defmodule GojoWeb.Plugs.Get_Subdomain_From_Host_PlugTest do
  use ExUnit.Case, async: true
  use Plug.Test
  use GojoWeb.ConnCase
  # use Gojo.DataCase

  alias Gojo.Accounts

  @opts GojoWeb.Plugs.Get_Subdomain_From_Host_Plug.init([])

  test "georgia subdomain is parsed correctly" do
    conn = conn(:get, "http://georgia.gojogo.com")
    conn = GojoWeb.Plugs.Get_Subdomain_From_Host_Plug.call(conn, @opts)
    assert conn.private[:subdomain] == "georgia"
    assert conn.assigns[:subdomain] == "georgia"
  end

  test "signup user on georgia.gojogo.com" do
    Accounts.create_tenant(%{
      name: "Georgia",
      subdomain: "georgia",
      domain: "georgia.com",
    })

    # We create the subdomain

    conn = conn(:get, "http://georgia.gojogo.com")
    conn = GojoWeb.Plugs.Get_Subdomain_From_Host_Plug.call(conn, @opts)
    subdomain = conn.private[:subdomain]

    store_front_tenant = Gojo.Accounts.find_tenant_by_subdomain(subdomain)
    IO.inspect(store_front_tenant)
    {:ok, user} = Accounts.register_user(store_front_tenant.id, %{
        name: Faker.Person.name(),
        email: Faker.Internet.email(),
        password: Faker.Lorem.characters(12) |> to_string,
      })

    assert user.tenant_id == store_front_tenant.id
  end
end

defmodule Gojo.TenantsTest do
  use ExUnit.Case, async: true
  use Gojo.DataCase
  alias Gojo.Tenants

  test "create new tenant schema" do
    assert {:ok, "tenant_1"} = Tenants.register_tenant("tenant_1")
    assert {:ok, "tenant_2"} = Tenants.register_tenant("tenant_2")
  end
end

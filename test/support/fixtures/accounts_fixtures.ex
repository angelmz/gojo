defmodule Gojo.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Gojo.Accounts` context.
  """

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password()
    })
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Gojo.Accounts.register_user()

    user
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end

  @doc """
  Generate a tenant.
  """
  def tenant_fixture(attrs \\ %{}) do
    {:ok, tenant} =
      attrs
      |> Enum.into(%{
        email: "some email",
        name: "some name"
      })
      |> Gojo.Accounts.create_tenant()

    tenant
  end

  def unique_tenant_email, do: "tenant#{System.unique_integer()}@example.com"
  def valid_tenant_password, do: "hello world!"

  def valid_tenant_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_tenant_email(),
      password: valid_tenant_password()
    })
  end

  def extract_tenant_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end
end

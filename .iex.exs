import ExUnit.Assertions
import IEx.Helpers

alias Gojo.Store
alias Gojo.Store.Product
alias Gojo.Accounts
alias Gojo.Accounts.User
alias Gojo.Accounts.Tenant
alias Gojo.Repo
alias Gojo.ShoppingCart
alias Gojo.ShoppingCart.Cart
alias Gojo.Orders
alias Gojo.Orders.Order

alias Gojo.Repo
# alias GojoWeb.UserAuth
alias Faker

import_if_available Ecto.Query

import_if_available Ecto.Changeset

defmodule H do
  def inspect() do
    Accounts.register_user(1, %{
      name: Faker.Person.name(),
      email: Faker.Internet.email(),
      password: Faker.Lorem.characters(12) |> to_string,
      role: :admin,
    })
  end
  def stats do
    EctoPSQLExtras.cache_hit(Gojo.Repo)
    EctoPSQLExtras.diagnose(Gojo.Repo)
  end
end

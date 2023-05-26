defmodule Gojo.Factory do
  alias Gojo.ShoppingCart
  alias Gojo.Accounts.Tenant
  alias Gojo.Accounts.User
  alias Gojo.Store.Product
  alias Gojo.ShoppingCart
  alias Gojo.ShoppingCart.Cart
  alias Gojo.Orders
  alias Gojo.Repo

  def insert(:tenant) do
    Tenant.registration_changeset(%Tenant{}, %{
      name: Faker.Company.name(),
      email: Faker.Internet.email(),
      subdomain: Faker.Internet.domain_word(),
      password: Faker.Lorem.characters(12) |> to_string,
    })
    |> Repo.insert!()
  end

  def insert(:user) do
    {:ok, tenant} = insert(:tenant)
    User.registration_changeset(%User{}, %{
      email: Faker.Internet.email(),
      password: Faker.Lorem.characters(12) |> to_string,
      tenant_id: tenant.id
    })
    |> Repo.insert!()
  end

  def insert(:product) do
    {:ok, seller} = insert(:user)
    Product.changeset(%Product{}, %{
      title: Faker.Lorem.sentence() |> String.slice(0, 255),
      description: Faker.Lorem.paragraph() |> String.slice(0, 255),
      price: :rand.uniform * 100 |> Float.round(2),
      sku: :rand.uniform(999999999) + 1,
      user_id: seller.id
    })
    |> Repo.insert!()
  end

  def insert(:cart) do
    {:ok, user} = insert(:user)
    Cart.changeset(%Cart{}, %{
      user_id: user.id
    })
    |> Repo.insert!()
  end

  # Work in progress
  def insert(:order) do
    {:ok, cart} = insert(:cart)
    {:ok, product} = insert(:product)
    ShoppingCart.add_item_to_cart(cart.id, product.id)
    Orders.complete_order(cart.id)
  end
end

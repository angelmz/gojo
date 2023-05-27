# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Gojo.Repo.insert!(%Gojo.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.
alias Gojo.Store.Product
alias Gojo.ShoppingCart
alias Gojo.ShoppingCart.Cart
alias Gojo.Orders

alias Gojo.Repo

Gojo.Accounts.create_tenant(%{
  name: "Alabama",
  domain: "alabama.com",
  subdomain: "alabama.gojogo.com",
})

Gojo.Accounts.create_tenant(%{
  name: "Kentucky",
  domain: "kentucky.com",
  subdomain: "kentucky.gojogo.com",
})

tenants =
  for _ <- 1..10 do
    domain = Faker.Internet.domain_word()
    Gojo.Accounts.create_tenant(%{
      name: Faker.Company.name(),
      domain: domain <> ".com",
      subdomain: domain <> ".gojogo.com",
    })
  end

users =
  for _ <- 1..10 do
    {:ok, tenant} = Enum.random(tenants)
    Gojo.Accounts.register_user(tenant.id, %{
      name: Faker.Person.name(),
      email: Faker.Internet.email(),
      password: Faker.Lorem.characters(12) |> to_string,
    })
  end

products =
  for _ <- 1..10 do
    {:ok, seller} = Enum.random(users)
    Product.changeset(%Product{}, %{
      title: Faker.Lorem.sentence() |> String.slice(0, 255),
      description: Faker.Lorem.paragraph() |> String.slice(0, 255),
      price: :rand.uniform * 100 |> Float.round(2),
      #Note not happy about abonding bigint for now.
      sku: :rand.uniform(999999999) + 1,
      user_id: seller.id
    })
    |> Repo.insert!
  end

_create_carts_and_add_products_to_carts =
  for {:ok, user} <- users do
    {:ok, cart} = ShoppingCart.create_cart(user.id)
    for _ <- 1..10 do
      product = Enum.random(products)

      ShoppingCart.add_item_to_cart(cart, product)
    end
  end

repoed_carts = Repo.all(Cart)

_orders_completed =
  for repoed_cart <- repoed_carts do
    cart = ShoppingCart.get_cart_by_user_id(repoed_cart.user_id)
    {:ok, _order} = Orders.complete_order(cart)
  end
# for {:ok, user_with_carts_and_items} <- users_with_carts_and_items do
#   # IO.inspect(user_with_carts_and_items)
#   cart = ShoppingCart.get_cart_by_user_id(user_with_carts_and_items.id)
#   #  {:ok, order} = Orders.complete_order(cart)
#   Orders.complete_order(cart)
# end

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

users =
  for _ <- 1..10 do
    Gojo.Accounts.register_user(%{
      email: Faker.Internet.email(),
      password: Faker.Lorem.characters(12) |> to_string,
    })
  end

products =
  for _ <- 1..50 do
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

create_carts_and_add_products_to_carts =
  for {:ok, user} <- users do
    {:ok, cart} = ShoppingCart.create_cart(user.id)
    for _ <- 1..10 do
      product = Enum.random(products)

      ShoppingCart.add_item_to_cart(cart, product)
    end
  end

repoed_carts = Repo.all(Cart)

orders_completed =
  for repoed_cart <- repoed_carts do
    cart = ShoppingCart.get_cart_by_user_id(repoed_cart.user_id)
    {:ok, order} = Orders.complete_order(cart)
  end
# for {:ok, user_with_carts_and_items} <- users_with_carts_and_items do
#   # IO.inspect(user_with_carts_and_items)
#   cart = ShoppingCart.get_cart_by_user_id(user_with_carts_and_items.id)
#   #  {:ok, order} = Orders.complete_order(cart)
#   Orders.complete_order(cart)
# end

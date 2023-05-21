defmodule Gojo.CartTest do
  use ExUnit.Case, async: false
  use Gojo.DataCase
  use GojoWeb.ConnCase

  alias Gojo.Store
  alias Gojo.Store.Product
  alias Gojo.Accounts
  alias Gojo.Accounts.User
  alias Gojo.Repo


  test "cart" do
    # cart`
    # Get users and products
    # For each user, create a cart
    # For each cart, add a random number of items
    users = Repo.all(User)
    products = Repo.all(Product)
    for user <- users do
      {:ok, cart} = ShoppingCart.create_cart(user.id)
      for _ <- 1..:rand.uniform(1..10) do
        product = Enum.random(products)
        ShoppingCart.add_item_to_cart(cart, product)
      end
    end

    # seller = Accounts.get_user_by_email("seller@seller.com")
    # {:ok, product} = Inventory.create_product(seller.id, mens_jacket)
    # customer1 = Accounts.get_user_by_email("danica@user.com")
    # {:ok, cart} = ShoppingCart.create_cart(customer1.id)
    # ShoppingCart.add_item_to_cart(cart, product)
    # cart = ShoppingCart.get_cart_by_user_id(2)
    # {:ok, order} = Orders.complete_order(cart)
  end
end

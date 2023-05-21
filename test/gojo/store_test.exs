defmodule Gojo.StoreTest do
  use ExUnit.Case, async: false
  use Gojo.DataCase
  use GojoWeb.ConnCase

  alias Gojo.Store
  alias Gojo.Store.Product
  alias Gojo.Accounts
  alias Gojo.Accounts.User
  alias Gojo.Repo


  describe "the process" do
    test "create users" do
      users =
        for _ <- 1..10 do
          user = %{
            email: Faker.Internet.email(),
            password: Faker.Lorem.characters(12) |> to_string
          }

          Accounts.register_user(user)
        end
    end

    test "create products that belong to 'seller' users" do
      users = Repo.all(User)
      products =
        for _ <- 1..100 do
          product =
            %{
              title: Faker.Lorem.sentence(),
              description: Faker.Lorem.paragraph(),
              price: :rand.uniform * 100 |> Float.round(2),
              #Note not happy about abonding bigint for now.
              sku: :rand.uniform * 100
            }

          {:ok, seller} = Enum.random(users)
          Store.create_product(seller.id, product)
        end
    end


    # test "create users buying items" do
    # # users

    # # products

    # # cart`
    # # Get users and products
    # # For each user, create a cart
    # # For each cart, add a random number of items
    #   users = Accounts.get_users()
    #   products = Inventory.get_products()
    #   for user <- users do
    #     {:ok, cart} = ShoppingCart.create_cart(user.id)
    #     for _ <- 1..:rand.uniform(1..10) do
    #       product = Enum.random(products)
    #       ShoppingCart.add_item_to_cart(cart, product)
    #     end
    #   end
    # # seller = Accounts.get_user_by_email("seller@seller.com")
    # # {:ok, product} = Inventory.create_product(seller.id, mens_jacket)
    # # customer1 = Accounts.get_user_by_email("danica@user.com")
    # # {:ok, cart} = ShoppingCart.create_cart(customer1.id)
    # # ShoppingCart.add_item_to_cart(cart, product)
    # # cart = ShoppingCart.get_cart_by_user_id(2)
    # # {:ok, order} = Orders.complete_order(cart)
    # ######### Acceptance test #########
    # end
  end
end

# defmodule Gojo.StoreTest do
#   use ExUnit.Case, async: false
#   use Gojo.DataCase
#   use Gojo.ConnCase

#   alias Gojo.Store
#   alias Gojo.Store.Product
#   alias Gojo.Accounts
#   alias Gojo.Accounts.User
#   alias Gojo.Repo


#   describe "the process" do
#     setup do
#       users =
#         for _ <- 1..10 do
#           user = %{
#             email: Faker.Internet.email(),
#             password: Faker.Lorem.characters(12) |> to_string
#           }

#           Accounts.register_user(user)
#         end
#       %{users: users}
#     end

#     setup do
#       products =
#         for _ <- 1..100 do
#           product =
#             %{
#               title: Faker.Lorem.sentence(),
#               description: Faker.Lorem.paragraph(),
#               price: :rand.uniform * 100 |> Float.round(2),
#               #Note not happy about abonding bigint for now.
#               sku: :rand.uniform * 100
#             }

#           {:ok, seller} = Enum.random(users)
#           Store.create_product(seller.id, product)
#         end
#     end

#     test "create products that belong to 'seller' users",%{users: users} do
#     end


#     test "create users buying items" do
#     # users

#     # products

#     # cart`
#     # Get users and products
#     # For each user, create a cart
#     # For each cart, add a random number of items
#       users = Accounts.get_users()
#       products = Inventory.get_products()
#       for user <- users do
#         {:ok, cart} = ShoppingCart.create_cart(user.id)
#         for _ <- 1..:rand.uniform(1..10) do
#           product = Enum.random(products)
#           ShoppingCart.add_item_to_cart(cart, product)
#         end
#       end
#     # seller = Accounts.get_user_by_email("seller@seller.com")
#     # {:ok, product} = Inventory.create_product(seller.id, mens_jacket)
#     # customer1 = Accounts.get_user_by_email("danica@user.com")
#     # {:ok, cart} = ShoppingCart.create_cart(customer1.id)
#     # ShoppingCart.add_item_to_cart(cart, product)
#     # cart = ShoppingCart.get_cart_by_user_id(2)
#     # {:ok, order} = Orders.complete_order(cart)
#     ######### Acceptance test #########
#     end
#   end
# end

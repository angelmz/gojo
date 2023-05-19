defmodule Gojo.StoreTest do
  use ExUnit.Case, async: true
  use Gojo.DataCase

  alias Gojo.Store
  alias Gojo.Store.Product
  alias Gojo.Accounts
  alias Gojo.Accounts.User
  alias Gojo.Repo


  describe "the process" do
    setup do
      users =
        for _ <- 1..10 do
          user = %{
            email: Faker.Internet.email(),
            password: Faker.Lorem.characters(12) |> to_string
          }

          Accounts.register_user(user)
        end
      %{users: users}
    end

    test "create products that belong to 'seller' users",%{users: users} do
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


    test "create users buying items" do

    end
  end
end

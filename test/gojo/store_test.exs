defmodule Gojo.StoreTest do
  use ExUnit.Case, async: true

  alias Gojo.Store
  alias Gojo.Store.Product
  alias Gojo.Accounts.User

  describe "the process" do
    test "create users" do
      for _ <- 1..100 do
        user = %{
          def email, do: Faker.Internet.email()
          def password, do: Faker.Lorem.characters(12) |> to_string
        }

        user = Accounts.create_user(user)
      end
    end

    test "create products that belong to 'seller' users" do
      for _ <- 1..100 do
        product =
          %{
            title: Faker.Lorem.sentence(),
            description: Faker.Lorem.paragraph(),
            price: :rand.uniform * 100 |> Float.round(2),  # This will generate a random decimal between 0.0 and 100.0
            serial_number: Faker.Code.isbn()  # Faker doesn't provide direct hex, so using isbn for unique code.
          }

        seller =
        Store.create_product(user_id, product)
      end
    end
  end
end

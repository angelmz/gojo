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
alias Gojo.Repo


users =
  for _ <- 1..10 do
    Gojo.Accounts.register_user(%{
      email: Faker.Internet.email(),
      password: Faker.Lorem.characters(12) |> to_string,
    })
  end

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

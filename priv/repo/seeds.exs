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


Gojo.Accounts.register_user(%{
  email: "user1@company.com",
  password: "123456789abc",
  password_confirmation: "123456789abc"
})

Gojo.Accounts.register_user(%{
  email: "user2@company.com",
  password: "123456789abc",
  password_confirmation: "123456789abc"
})

Gojo.Accounts.register_user(%{
  email: "user3@company.com",
  password: "123456789abc",
  password_confirmation: "123456789abc"
})

Gojo.Accounts.register_user(%{
  email: "user4@company.com",
  password: "123456789abc",
  password_confirmation: "123456789abc"
})

Gojo.Accounts.register_user(%{
  email: "user5@company.com",
  password: "123456789abc",
  password_confirmation: "123456789abc"
})

Gojo.Accounts.register_user(%{
  email: "user6@company.com",
  password: "123456789abc",
  password_confirmation: "123456789abc"
})

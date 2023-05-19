import ExUnit.Assertions
import IEx.Helpers

alias Gojo.Store
alias Gojo.Store.Product
alias Gojo.Accounts
alias Gojo.Accounts.User
alias Gojo.Repo
# alias GojoWeb.UserAuth
alias Faker

import_if_available Ecto.Query

import_if_available Ecto.Changeset

defmodule H do
  def stats do
    EctoPSQLExtras.cache_hit(Gojo.Repo)
    EctoPSQLExtras.diagnose(Gojo.Repo)
  end
end

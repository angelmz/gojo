defmodule Gojo.Store do
  alias Gojo.Store.Product
  alias Gojo.Repo

  def create_product(user_id, attrs \\ %{}) do
    %Product{user_id: user_id}
    |> Product.changeset(attrs)
    |> Repo.insert()
  end
end

defmodule Gojo.Store.Product do
  use Ecto.Schema
  import Ecto.Changeset
  # alias Gojo.Catalog.Category


  schema "products" do
    field :description, :string
    field :price, :decimal
    field :sku, :integer
    field :title, :string

    belongs_to :user, Gojo.Accounts.User
    # many_to_many :categories, Category, join_through: "product_categories", on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(product, attrs) do
    product
    |> cast(attrs, [:title, :price, :description, :sku, :user_id])
    |> validate_required([:title, :price, :description, :sku, :user_id])
    |> unique_constraint([:sku, :user_id])
    |> foreign_key_constraint(:user_id)
  end
end

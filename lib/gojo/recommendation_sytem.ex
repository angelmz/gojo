defmodule Gojo.RecommendationSystem do
  alias Gojo.Repo
  alias Gojo.ShoppingCart.Cart
  alias Gojo.Orders.Order
  alias Gojo.Store.Product
  import Matrex

  def build_user_product_matrix do
    query = from(o in Order,
                group_by: [o.user_id, o.product_id],
                select: %{user_id: o.user_id, product_id: o.product_id, count: count(o.id)})
    user_product_counts = Repo.all(query)

    # Assume that user_ids and product_ids are consecutive integers starting from 1.
    # You might need to map user_ids and product_ids to consecutive integers if that's not the case.
    n_users = Repo.aggregate(User, :count, :id)
    n_products = Repo.aggregate(Product, :count, :id)

    # Initialize the matrix with zeros
    matrix = Matrex.zeros(n_users, n_products)

    # Set the number of purchases for each user-product pair
    for %{user_id: user_id, product_id: product_id, count: count} <- user_product_counts do
      set_in(matrix[{user_id - 1, product_id - 1}], count)
    end

    matrix
  end

  def factorize_matrix(matrix) do
    # Factorize the matrix using Matrex
    {u, s, vt} = svd(matrix)
    {u, s, vt}
  end
end

defmodule Gojo.Recommendation do
  use Ecto.Schema

  schema "recommendations" do
    belongs_to :user, Gojo.Accounts.User
    belongs_to :product, Gojo.Store.Product
    field :rating, :float
    timestamps()
  end
end

defmodule Gojo.RecommendationWorker do
  use Oban.Worker, queue: :default, max_attempts: 5

  alias Gojo.RecommendationSystem
  alias Gojo.Recommendation
  alias Gojo.Repo

  def perform(%Oban.Job{args: args}) do
    ####### New Users #######
    # Check if the user is new (i.e., has no purchases)
    new_user_query = from(u in User, left_join: o in Order, on: o.user_id == u.id, where: is_nil(o.id), select: u.id)
    new_users = Repo.all(new_user_query)

    # Get popular products
    popular_products_query = from(p in Product, join: o in Order, on: o.product_id == p.id, group_by: p.id, order_by: count(o.id), limit: 10, select: p.id)
    popular_products = Repo.all(popular_products_query)

    # Recommend popular products to new users
    for user_id <- new_users, product_id <- popular_products do
      %Recommendation{user_id: user_id, product_id: product_id, rating: 0}
      |> Repo.insert()
    end
    ####### New Users #######

    ####### New Products #######
    # Check if the product is new (i.e., has no purchases)
    new_product_query = from(p in Product, left_join: o in Order, on: o.product_id == p.id, where: is_nil(o.id), select: p.id)
    new_products = Repo.all(new_product_query)

    # For each new product, find users who have bought from this category before
    for new_product <- new_products do
      similar_users_query = from(u in User, join: o in Order, on: o.user_id == u.id, join: p in Product, on: o.product_id == p.id, where: p.category == new_product.category, select: u.id)
      similar_users = Repo.all(similar_users_query)

      # Recommend the new product to these users
      for user_id <- similar_users do
        %Recommendation{user_id: user_id, product_id: new_product.id, rating: 0}
        |> Repo.insert()
      end
    end
    ####### New Products #######
    user_product_matrix = RecommendationSystem.build_user_product_matrix()
    {u, s, vt} = RecommendationSystem.factorize_matrix(user_product_matrix)
    predicted_ratings = Matrex.dot(Matrex.dot(u, s), vt)

    for user_id <- 1..Matrex.shape(predicted_ratings) |> elem(0) do
      for product_id <- 1..Matrex.shape(predicted_ratings) |> elem(1) do
        rating = get_in(predicted_ratings, [user_id - 1, product_id - 1])

        # Save the predicted rating as a recommendation.
        # You might want to only save the top-N recommendations for each user,
        # or set a threshold for the rating, to reduce the size of the recommendations table.
        %Recommendation{user_id: user_id, product_id: product_id, rating: rating}
        |> Repo.insert()
      end
    end
  end


end

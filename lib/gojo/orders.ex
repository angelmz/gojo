defmodule Gojo.Orders do
  @moduledoc """
  The Orders context.
  """

  import Ecto.Query, warn: false
  alias Gojo.Repo

  alias Gojo.Orders.{Order}
  alias Gojo.ShoppingCart

  def list_orders do
    Repo.all(Order)
  end

  def get_order!(user_id, id) do
    Order
    |> Repo.get_by!(id: id, user_id: user_id)
    |> Repo.preload([line_items: [:product]])
  end

  def complete_order(%ShoppingCart.Cart{} = cart) do
    line_items =
      Enum.map(cart.items, fn item ->
        %{product_id: item.product_id, price: item.product.price, quantity: item.quantity}
      end)

    order =
      Ecto.Changeset.change(%Order{},
        user_id: cart.user_id,
        total_price: ShoppingCart.total_cart_price(cart),
        line_items: line_items
      )

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:order, order)
    |> Ecto.Multi.run(:prune_cart, fn _repo, _changes ->
      ShoppingCart.prune_cart_items(cart)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{order: order}} -> {:ok, order}
      {:error, name, value, _changes_so_far} -> {:error, {name, value}}
    end
  end


  @doc """
  Updates a order.

  ## Examples

      iex> update_order(order, %{field: new_value})
      {:ok, %Order{}}

      iex> update_order(order, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_order(%Order{} = order, attrs) do
    order
    |> Order.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a order.

  ## Examples

      iex> delete_order(order)
      {:ok, %Order{}}

      iex> delete_order(order)
      {:error, %Ecto.Changeset{}}

  """
  def delete_order(%Order{} = order) do
    Repo.delete(order)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking order changes.

  ## Examples

      iex> change_order(order)
      %Ecto.Changeset{data: %Order{}}

  """
  def change_order(%Order{} = order, attrs \\ %{}) do
    Order.changeset(order, attrs)
  end
end

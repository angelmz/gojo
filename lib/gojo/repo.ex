defmodule Gojo.Repo do
  use Ecto.Repo,
    otp_app: :gojo,
    adapter: Ecto.Adapters.Postgres
end

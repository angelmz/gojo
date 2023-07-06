defmodule Gojo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  # import OpentelemetryEcto

  @impl true
  def start(_type, _args) do
    :opentelemetry_cowboy.setup()
    OpentelemetryPhoenix.setup(adapter: :cowboy2)
    OpentelemetryEcto.setup([:gojo, :repo])

    children = [
      # Start the Telemetry supervisor
      GojoWeb.Telemetry,
      # Start the Ecto repository
      Gojo.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: Gojo.PubSub},
      # Start Finch
      {Finch, name: Gojo.Finch},
      # Start the Endpoint (http/https)
      GojoWeb.Endpoint
      # Start a worker by calling: Gojo.Worker.start_link(arg)
      # {Gojo.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Gojo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    GojoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

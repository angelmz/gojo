defmodule GojoWeb.Router do
  use GojoWeb, :router

  import GojoWeb.TenantAuth

  import GojoWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {GojoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_tenant
    plug :fetch_current_user
    plug GojoWeb.Plugs.Get_Subdomain_From_Host_Plug
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # pipeline :subdomain do
  #   plug :identify_subdomain
  # end

  # defp identify_subdomain(conn, _) do
  #   [subdomain | _] = conn.host |> String.split(".") |> Enum.reverse
  #   assign(conn, :subdomain, subdomain)
  # end

  # scope "/", GojoWeb do
  #   pipe_through [:browser, :subdomain]

  #   get "/", TenantController, :index
  #   # Add more routes specific to tenants here
  # end

  scope "/", GojoWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", GojoWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:gojo, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: GojoWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", GojoWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{GojoWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", GojoWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{GojoWeb.UserAuth, :ensure_authenticated}] do
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
    end
  end

  scope "/", GojoWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{GojoWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end

  ## Authentication routes

  scope "/", GojoWeb do
    pipe_through [:browser, :redirect_if_tenant_is_authenticated]

    live_session :redirect_if_tenant_is_authenticated,
      on_mount: [{GojoWeb.TenantAuth, :redirect_if_tenant_is_authenticated}] do
      live "/tenants/register", TenantRegistrationLive, :new
      live "/tenants/log_in", TenantLoginLive, :new
      live "/tenants/reset_password", TenantForgotPasswordLive, :new
      live "/tenants/reset_password/:token", TenantResetPasswordLive, :edit
    end

    post "/tenants/log_in", TenantSessionController, :create
  end

  scope "/", GojoWeb do
    pipe_through [:browser, :require_authenticated_tenant]

    live_session :require_authenticated_tenant,
      on_mount: [{GojoWeb.TenantAuth, :ensure_authenticated}] do
      live "/tenants/settings", TenantSettingsLive, :edit
      live "/tenants/settings/confirm_email/:token", TenantSettingsLive, :confirm_email
    end
  end

  scope "/", GojoWeb do
    pipe_through [:browser]

    delete "/tenants/log_out", TenantSessionController, :delete

    live_session :current_tenant,
      on_mount: [{GojoWeb.TenantAuth, :mount_current_tenant}] do
      live "/tenants/confirm/:token", TenantConfirmationLive, :edit
      live "/tenants/confirm", TenantConfirmationInstructionsLive, :new
    end
  end
end

defmodule Gojo.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Gojo.Repo

  alias Gojo.Accounts.{User, UserToken, UserNotifier}

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(tenant_id, attrs) do
    %User{tenant_id: tenant_id}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false, validate_email: false)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}) do
    User.email_changeset(user, attrs, validate_email: false)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_user_email(user, "valid password", %{email: ...})
      {:ok, %User{}}

      iex> apply_user_email(user, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_user_email(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
         %UserToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(user_email_multi(user, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp user_email_multi(user, email, context) do
    changeset =
      user
      |> User.email_changeset(%{email: email})
      |> User.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, [context]))
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm_email/#{&1})")
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}) do
    User.password_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Updates the user password.

  ## Examples

      iex> update_user_password(user, "valid password", %{password: ...})
      {:ok, %User{}}

      iex> update_user_password(user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc ~S"""
  Delivers the confirmation email instructions to the given user.

  ## Examples

      iex> deliver_user_confirmation_instructions(user, &url(~p"/users/confirm/#{&1}"))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_user_confirmation_instructions(confirmed_user, &url(~p"/users/confirm/#{&1}"))
      {:error, :already_confirmed}

  """
  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user_token} = UserToken.build_email_token(user, "confirm")
      Repo.insert!(user_token)
      UserNotifier.deliver_confirmation_instructions(user, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a user by the given token.

  If the token matches, the user account is marked as confirmed
  and the token is deleted.
  """
  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, ["confirm"]))
  end

  ## Reset password

  @doc ~S"""
  Delivers the reset password email to the given user.

  ## Examples

      iex> deliver_user_reset_password_instructions(user, &url(~p"/users/reset_password/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)
    UserNotifier.deliver_reset_password_instructions(user, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the user by reset password token.

  ## Examples

      iex> get_user_by_reset_password_token("validtoken")
      %User{}

      iex> get_user_by_reset_password_token("invalidtoken")
      nil

  """
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Resets the user password.

  ## Examples

      iex> reset_user_password(user, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %User{}}

      iex> reset_user_password(user, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_user_password(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  alias Gojo.Accounts.{Tenant, TenantToken, TenantNotifier}

  ## Database getters

  @doc """
  Gets a tenant by email.

  ## Examples

      iex> get_tenant_by_email("foo@example.com")
      %Tenant{}

      iex> get_tenant_by_email("unknown@example.com")
      nil

  """
  def get_tenant_by_email(email) when is_binary(email) do
    Repo.get_by(Tenant, email: email)
  end

  @doc """
  Gets a tenant by email and password.

  ## Examples

      iex> get_tenant_by_email_and_password("foo@example.com", "correct_password")
      %Tenant{}

      iex> get_tenant_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_tenant_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    tenant = Repo.get_by(Tenant, email: email)
    if Tenant.valid_password?(tenant, password), do: tenant
  end

  @doc """
  Gets a single tenant.

  Raises `Ecto.NoResultsError` if the Tenant does not exist.

  ## Examples

      iex> get_tenant!(123)
      %Tenant{}

      iex> get_tenant!(456)
      ** (Ecto.NoResultsError)

  """
  def get_tenant!(id), do: Repo.get!(Tenant, id)

  ## Tenant registration

  @doc """
  Registers a tenant.

  ## Examples

      iex> register_tenant(%{field: value})
      {:ok, %Tenant{}}

      iex> register_tenant(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_tenant(attrs) do
    %Tenant{}
    |> Tenant.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking tenant changes.

  ## Examples

      iex> change_tenant_registration(tenant)
      %Ecto.Changeset{data: %Tenant{}}

  """
  def change_tenant_registration(%Tenant{} = tenant, attrs \\ %{}) do
    Tenant.registration_changeset(tenant, attrs, hash_password: false, validate_email: false)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the tenant email.

  ## Examples

      iex> change_tenant_email(tenant)
      %Ecto.Changeset{data: %Tenant{}}

  """
  def change_tenant_email(tenant, attrs \\ %{}) do
    Tenant.email_changeset(tenant, attrs, validate_email: false)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_tenant_email(tenant, "valid password", %{email: ...})
      {:ok, %Tenant{}}

      iex> apply_tenant_email(tenant, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_tenant_email(tenant, password, attrs) do
    tenant
    |> Tenant.email_changeset(attrs)
    |> Tenant.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the tenant email using the given token.

  If the token matches, the tenant email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_tenant_email(tenant, token) do
    context = "change:#{tenant.email}"

    with {:ok, query} <- TenantToken.verify_change_email_token_query(token, context),
         %TenantToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(tenant_email_multi(tenant, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp tenant_email_multi(tenant, email, context) do
    changeset =
      tenant
      |> Tenant.email_changeset(%{email: email})
      |> Tenant.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:tenant, changeset)
    |> Ecto.Multi.delete_all(:tokens, TenantToken.tenant_and_contexts_query(tenant, [context]))
  end

  @doc ~S"""
  Delivers the update email instructions to the given tenant.

  ## Examples

      iex> deliver_tenant_update_email_instructions(tenant, current_email, &url(~p"/tenants/settings/confirm_email/#{&1})")
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_tenant_update_email_instructions(%Tenant{} = tenant, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, tenant_token} = TenantToken.build_email_token(tenant, "change:#{current_email}")

    Repo.insert!(tenant_token)
    TenantNotifier.deliver_update_email_instructions(tenant, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the tenant password.

  ## Examples

      iex> change_tenant_password(tenant)
      %Ecto.Changeset{data: %Tenant{}}

  """
  def change_tenant_password(tenant, attrs \\ %{}) do
    Tenant.password_changeset(tenant, attrs, hash_password: false)
  end

  @doc """
  Updates the tenant password.

  ## Examples

      iex> update_tenant_password(tenant, "valid password", %{password: ...})
      {:ok, %Tenant{}}

      iex> update_tenant_password(tenant, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_tenant_password(tenant, password, attrs) do
    changeset =
      tenant
      |> Tenant.password_changeset(attrs)
      |> Tenant.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:tenant, changeset)
    |> Ecto.Multi.delete_all(:tokens, TenantToken.tenant_and_contexts_query(tenant, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{tenant: tenant}} -> {:ok, tenant}
      {:error, :tenant, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_tenant_session_token(tenant) do
    {token, tenant_token} = TenantToken.build_session_token(tenant)
    Repo.insert!(tenant_token)
    token
  end

  @doc """
  Gets the tenant with the given signed token.
  """
  def get_tenant_by_session_token(token) do
    {:ok, query} = TenantToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_tenant_session_token(token) do
    Repo.delete_all(TenantToken.token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc ~S"""
  Delivers the confirmation email instructions to the given tenant.

  ## Examples

      iex> deliver_tenant_confirmation_instructions(tenant, &url(~p"/tenants/confirm/#{&1}"))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_tenant_confirmation_instructions(confirmed_tenant, &url(~p"/tenants/confirm/#{&1}"))
      {:error, :already_confirmed}

  """
  def deliver_tenant_confirmation_instructions(%Tenant{} = tenant, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if tenant.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, tenant_token} = TenantToken.build_email_token(tenant, "confirm")
      Repo.insert!(tenant_token)
      TenantNotifier.deliver_confirmation_instructions(tenant, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a tenant by the given token.

  If the token matches, the tenant account is marked as confirmed
  and the token is deleted.
  """
  def confirm_tenant(token) do
    with {:ok, query} <- TenantToken.verify_email_token_query(token, "confirm"),
         %Tenant{} = tenant <- Repo.one(query),
         {:ok, %{tenant: tenant}} <- Repo.transaction(confirm_tenant_multi(tenant)) do
      {:ok, tenant}
    else
      _ -> :error
    end
  end

  defp confirm_tenant_multi(tenant) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:tenant, Tenant.confirm_changeset(tenant))
    |> Ecto.Multi.delete_all(:tokens, TenantToken.tenant_and_contexts_query(tenant, ["confirm"]))
  end

  ## Reset password

  @doc ~S"""
  Delivers the reset password email to the given tenant.

  ## Examples

      iex> deliver_tenant_reset_password_instructions(tenant, &url(~p"/tenants/reset_password/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_tenant_reset_password_instructions(%Tenant{} = tenant, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, tenant_token} = TenantToken.build_email_token(tenant, "reset_password")
    Repo.insert!(tenant_token)
    TenantNotifier.deliver_reset_password_instructions(tenant, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the tenant by reset password token.

  ## Examples

      iex> get_tenant_by_reset_password_token("validtoken")
      %Tenant{}

      iex> get_tenant_by_reset_password_token("invalidtoken")
      nil

  """
  def get_tenant_by_reset_password_token(token) do
    with {:ok, query} <- TenantToken.verify_email_token_query(token, "reset_password"),
         %Tenant{} = tenant <- Repo.one(query) do
      tenant
    else
      _ -> nil
    end
  end

  @doc """
  Resets the tenant password.

  ## Examples

      iex> reset_tenant_password(tenant, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %Tenant{}}

      iex> reset_tenant_password(tenant, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_tenant_password(tenant, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:tenant, Tenant.password_changeset(tenant, attrs))
    |> Ecto.Multi.delete_all(:tokens, TenantToken.tenant_and_contexts_query(tenant, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{tenant: tenant}} -> {:ok, tenant}
      {:error, :tenant, changeset, _} -> {:error, changeset}
    end
  end
end

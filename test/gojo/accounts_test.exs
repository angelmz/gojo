defmodule Gojo.AccountsTest do
  use Gojo.DataCase

  alias Gojo.Accounts

  import Gojo.AccountsFixtures
  alias Gojo.Accounts.{User, UserToken}

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user_by_email(user.email)
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the user if the password is not valid" do
      user = user_fixture()
      refute Accounts.get_user_by_email_and_password(user.email, "invalid")
    end

    test "returns the user if the email and password are valid" do
      %{id: id} = user = user_fixture()

      assert %User{id: ^id} =
               Accounts.get_user_by_email_and_password(user.email, valid_user_password())
    end
  end

  describe "get_user!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user!(-1)
      end
    end

    test "returns the user with the given id" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user!(user.id)
    end
  end

  describe "register_user/1" do
    test "requires email and password to be set" do
      {:error, changeset} = Accounts.register_user(%{})

      assert %{
               password: ["can't be blank"],
               email: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates email and password when given" do
      {:error, changeset} = Accounts.register_user(%{email: "not valid", password: "not valid"})

      assert %{
               email: ["must have the @ sign and no spaces"],
               password: ["should be at least 12 character(s)"]
             } = errors_on(changeset)
    end

    test "validates maximum values for email and password for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.register_user(%{email: too_long, password: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates email uniqueness" do
      %{email: email} = user_fixture()
      {:error, changeset} = Accounts.register_user(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} = Accounts.register_user(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers users with a hashed password" do
      email = unique_user_email()
      {:ok, user} = Accounts.register_user(valid_user_attributes(email: email))
      assert user.email == email
      assert is_binary(user.hashed_password)
      assert is_nil(user.confirmed_at)
      assert is_nil(user.password)
    end
  end

  describe "change_user_registration/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_registration(%User{})
      assert changeset.required == [:password, :email]
    end

    test "allows fields to be set" do
      email = unique_user_email()
      password = valid_user_password()

      changeset =
        Accounts.change_user_registration(
          %User{},
          valid_user_attributes(email: email, password: password)
        )

      assert changeset.valid?
      assert get_change(changeset, :email) == email
      assert get_change(changeset, :password) == password
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "change_user_email/2" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_email(%User{})
      assert changeset.required == [:email]
    end
  end

  describe "apply_user_email/3" do
    setup do
      %{user: user_fixture()}
    end

    test "requires email to change", %{user: user} do
      {:error, changeset} = Accounts.apply_user_email(user, valid_user_password(), %{})
      assert %{email: ["did not change"]} = errors_on(changeset)
    end

    test "validates email", %{user: user} do
      {:error, changeset} =
        Accounts.apply_user_email(user, valid_user_password(), %{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum value for email for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.apply_user_email(user, valid_user_password(), %{email: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness", %{user: user} do
      %{email: email} = user_fixture()
      password = valid_user_password()

      {:error, changeset} = Accounts.apply_user_email(user, password, %{email: email})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "validates current password", %{user: user} do
      {:error, changeset} =
        Accounts.apply_user_email(user, "invalid", %{email: unique_user_email()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the email without persisting it", %{user: user} do
      email = unique_user_email()
      {:ok, user} = Accounts.apply_user_email(user, valid_user_password(), %{email: email})
      assert user.email == email
      assert Accounts.get_user!(user.id).email != email
    end
  end

  describe "deliver_user_update_email_instructions/3" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(user, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "change:current@example.com"
    end
  end

  describe "update_user_email/2" do
    setup do
      user = user_fixture()
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{user: user, token: token, email: email}
    end

    test "updates the email with a valid token", %{user: user, token: token, email: email} do
      assert Accounts.update_user_email(user, token) == :ok
      changed_user = Repo.get!(User, user.id)
      assert changed_user.email != user.email
      assert changed_user.email == email
      assert changed_user.confirmed_at
      assert changed_user.confirmed_at != user.confirmed_at
      refute Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email with invalid token", %{user: user} do
      assert Accounts.update_user_email(user, "oops") == :error
      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if user email changed", %{user: user, token: token} do
      assert Accounts.update_user_email(%{user | email: "current@example.com"}, token) == :error
      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.update_user_email(user, token) == :error
      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "change_user_password/2" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_password(%User{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Accounts.change_user_password(%User{}, %{
          "password" => "new valid password"
        })

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_user_password/3" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        Accounts.update_user_password(user, valid_user_password(), %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_user_password(user, valid_user_password(), %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates current password", %{user: user} do
      {:error, changeset} =
        Accounts.update_user_password(user, "invalid", %{password: valid_user_password()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{user: user} do
      {:ok, user} =
        Accounts.update_user_password(user, valid_user_password(), %{
          password: "new valid password"
        })

      assert is_nil(user.password)
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Accounts.generate_user_session_token(user)

      {:ok, _} =
        Accounts.update_user_password(user, valid_user_password(), %{
          password: "new valid password"
        })

      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "generate_user_session_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.context == "session"

      # Creating the same token for another user should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%UserToken{
          token: user_token.token,
          user_id: user_fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert session_user = Accounts.get_user_by_session_token(token)
      assert session_user.id == user.id
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_session_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "delete_user_session_token/1" do
    test "deletes the token" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      assert Accounts.delete_user_session_token(token) == :ok
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "deliver_user_confirmation_instructions/2" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_confirmation_instructions(user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "confirm"
    end
  end

  describe "confirm_user/1" do
    setup do
      user = user_fixture()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_confirmation_instructions(user, url)
        end)

      %{user: user, token: token}
    end

    test "confirms the email with a valid token", %{user: user, token: token} do
      assert {:ok, confirmed_user} = Accounts.confirm_user(token)
      assert confirmed_user.confirmed_at
      assert confirmed_user.confirmed_at != user.confirmed_at
      assert Repo.get!(User, user.id).confirmed_at
      refute Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not confirm with invalid token", %{user: user} do
      assert Accounts.confirm_user("oops") == :error
      refute Repo.get!(User, user.id).confirmed_at
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not confirm email if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.confirm_user(token) == :error
      refute Repo.get!(User, user.id).confirmed_at
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "deliver_user_reset_password_instructions/2" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_reset_password_instructions(user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "reset_password"
    end
  end

  describe "get_user_by_reset_password_token/1" do
    setup do
      user = user_fixture()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_reset_password_instructions(user, url)
        end)

      %{user: user, token: token}
    end

    test "returns the user with valid token", %{user: %{id: id}, token: token} do
      assert %User{id: ^id} = Accounts.get_user_by_reset_password_token(token)
      assert Repo.get_by(UserToken, user_id: id)
    end

    test "does not return the user with invalid token", %{user: user} do
      refute Accounts.get_user_by_reset_password_token("oops")
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not return the user if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_user_by_reset_password_token(token)
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "reset_user_password/2" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        Accounts.reset_user_password(user, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.reset_user_password(user, %{password: too_long})
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{user: user} do
      {:ok, updated_user} = Accounts.reset_user_password(user, %{password: "new valid password"})
      assert is_nil(updated_user.password)
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Accounts.generate_user_session_token(user)
      {:ok, _} = Accounts.reset_user_password(user, %{password: "new valid password"})
      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "inspect/2 for the User module" do
    test "does not include password" do
      refute inspect(%User{password: "123456"}) =~ "password: \"123456\""
    end
  end

  describe "tenants" do
    alias Gojo.Accounts.Tenant

    import Gojo.AccountsFixtures

    @invalid_attrs %{email: nil, name: nil}

    test "list_tenants/0 returns all tenants" do
      tenant = tenant_fixture()
      assert Accounts.list_tenants() == [tenant]
    end

    test "get_tenant!/1 returns the tenant with given id" do
      tenant = tenant_fixture()
      assert Accounts.get_tenant!(tenant.id) == tenant
    end

    test "create_tenant/1 with valid data creates a tenant" do
      valid_attrs = %{email: "some email", name: "some name"}

      assert {:ok, %Tenant{} = tenant} = Accounts.create_tenant(valid_attrs)
      assert tenant.email == "some email"
      assert tenant.name == "some name"
    end

    test "create_tenant/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.create_tenant(@invalid_attrs)
    end

    test "update_tenant/2 with valid data updates the tenant" do
      tenant = tenant_fixture()
      update_attrs = %{email: "some updated email", name: "some updated name"}

      assert {:ok, %Tenant{} = tenant} = Accounts.update_tenant(tenant, update_attrs)
      assert tenant.email == "some updated email"
      assert tenant.name == "some updated name"
    end

    test "update_tenant/2 with invalid data returns error changeset" do
      tenant = tenant_fixture()
      assert {:error, %Ecto.Changeset{}} = Accounts.update_tenant(tenant, @invalid_attrs)
      assert tenant == Accounts.get_tenant!(tenant.id)
    end

    test "delete_tenant/1 deletes the tenant" do
      tenant = tenant_fixture()
      assert {:ok, %Tenant{}} = Accounts.delete_tenant(tenant)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_tenant!(tenant.id) end
    end

    test "change_tenant/1 returns a tenant changeset" do
      tenant = tenant_fixture()
      assert %Ecto.Changeset{} = Accounts.change_tenant(tenant)
    end
  end

  import Gojo.AccountsFixtures
  alias Gojo.Accounts.{Tenant, TenantToken}

  describe "get_tenant_by_email/1" do
    test "does not return the tenant if the email does not exist" do
      refute Accounts.get_tenant_by_email("unknown@example.com")
    end

    test "returns the tenant if the email exists" do
      %{id: id} = tenant = tenant_fixture()
      assert %Tenant{id: ^id} = Accounts.get_tenant_by_email(tenant.email)
    end
  end

  describe "get_tenant_by_email_and_password/2" do
    test "does not return the tenant if the email does not exist" do
      refute Accounts.get_tenant_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the tenant if the password is not valid" do
      tenant = tenant_fixture()
      refute Accounts.get_tenant_by_email_and_password(tenant.email, "invalid")
    end

    test "returns the tenant if the email and password are valid" do
      %{id: id} = tenant = tenant_fixture()

      assert %Tenant{id: ^id} =
               Accounts.get_tenant_by_email_and_password(tenant.email, valid_tenant_password())
    end
  end

  describe "get_tenant!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_tenant!(-1)
      end
    end

    test "returns the tenant with the given id" do
      %{id: id} = tenant = tenant_fixture()
      assert %Tenant{id: ^id} = Accounts.get_tenant!(tenant.id)
    end
  end

  describe "create_tenant/1" do
    test "requires email and password to be set" do
      {:error, changeset} = Accounts.create_tenant(%{})

      assert %{
               password: ["can't be blank"],
               email: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates email and password when given" do
      {:error, changeset} = Accounts.create_tenant(%{email: "not valid", password: "not valid"})

      assert %{
               email: ["must have the @ sign and no spaces"],
               password: ["should be at least 12 character(s)"]
             } = errors_on(changeset)
    end

    test "validates maximum values for email and password for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.create_tenant(%{email: too_long, password: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates email uniqueness" do
      %{email: email} = tenant_fixture()
      {:error, changeset} = Accounts.create_tenant(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} = Accounts.create_tenant(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers tenants with a hashed password" do
      email = unique_tenant_email()
      {:ok, tenant} = Accounts.create_tenant(valid_tenant_attributes(email: email))
      assert tenant.email == email
      assert is_binary(tenant.hashed_password)
      assert is_nil(tenant.confirmed_at)
      assert is_nil(tenant.password)
    end
  end

  describe "change_tenant_registration/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_tenant_registration(%Tenant{})
      assert changeset.required == [:password, :email]
    end

    test "allows fields to be set" do
      email = unique_tenant_email()
      password = valid_tenant_password()

      changeset =
        Accounts.change_tenant_registration(
          %Tenant{},
          valid_tenant_attributes(email: email, password: password)
        )

      assert changeset.valid?
      assert get_change(changeset, :email) == email
      assert get_change(changeset, :password) == password
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "change_tenant_email/2" do
    test "returns a tenant changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_tenant_email(%Tenant{})
      assert changeset.required == [:email]
    end
  end

  describe "apply_tenant_email/3" do
    setup do
      %{tenant: tenant_fixture()}
    end

    test "requires email to change", %{tenant: tenant} do
      {:error, changeset} = Accounts.apply_tenant_email(tenant, valid_tenant_password(), %{})
      assert %{email: ["did not change"]} = errors_on(changeset)
    end

    test "validates email", %{tenant: tenant} do
      {:error, changeset} =
        Accounts.apply_tenant_email(tenant, valid_tenant_password(), %{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum value for email for security", %{tenant: tenant} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.apply_tenant_email(tenant, valid_tenant_password(), %{email: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness", %{tenant: tenant} do
      %{email: email} = tenant_fixture()
      password = valid_tenant_password()

      {:error, changeset} = Accounts.apply_tenant_email(tenant, password, %{email: email})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "validates current password", %{tenant: tenant} do
      {:error, changeset} =
        Accounts.apply_tenant_email(tenant, "invalid", %{email: unique_tenant_email()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the email without persisting it", %{tenant: tenant} do
      email = unique_tenant_email()
      {:ok, tenant} = Accounts.apply_tenant_email(tenant, valid_tenant_password(), %{email: email})
      assert tenant.email == email
      assert Accounts.get_tenant!(tenant.id).email != email
    end
  end

  describe "deliver_tenant_update_email_instructions/3" do
    setup do
      %{tenant: tenant_fixture()}
    end

    test "sends token through notification", %{tenant: tenant} do
      token =
        extract_tenant_token(fn url ->
          Accounts.deliver_tenant_update_email_instructions(tenant, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert tenant_token = Repo.get_by(TenantToken, token: :crypto.hash(:sha256, token))
      assert tenant_token.tenant_id == tenant.id
      assert tenant_token.sent_to == tenant.email
      assert tenant_token.context == "change:current@example.com"
    end
  end

  describe "update_tenant_email/2" do
    setup do
      tenant = tenant_fixture()
      email = unique_tenant_email()

      token =
        extract_tenant_token(fn url ->
          Accounts.deliver_tenant_update_email_instructions(%{tenant | email: email}, tenant.email, url)
        end)

      %{tenant: tenant, token: token, email: email}
    end

    test "updates the email with a valid token", %{tenant: tenant, token: token, email: email} do
      assert Accounts.update_tenant_email(tenant, token) == :ok
      changed_tenant = Repo.get!(Tenant, tenant.id)
      assert changed_tenant.email != tenant.email
      assert changed_tenant.email == email
      assert changed_tenant.confirmed_at
      assert changed_tenant.confirmed_at != tenant.confirmed_at
      refute Repo.get_by(TenantToken, tenant_id: tenant.id)
    end

    test "does not update email with invalid token", %{tenant: tenant} do
      assert Accounts.update_tenant_email(tenant, "oops") == :error
      assert Repo.get!(Tenant, tenant.id).email == tenant.email
      assert Repo.get_by(TenantToken, tenant_id: tenant.id)
    end

    test "does not update email if tenant email changed", %{tenant: tenant, token: token} do
      assert Accounts.update_tenant_email(%{tenant | email: "current@example.com"}, token) == :error
      assert Repo.get!(Tenant, tenant.id).email == tenant.email
      assert Repo.get_by(TenantToken, tenant_id: tenant.id)
    end

    test "does not update email if token expired", %{tenant: tenant, token: token} do
      {1, nil} = Repo.update_all(TenantToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.update_tenant_email(tenant, token) == :error
      assert Repo.get!(Tenant, tenant.id).email == tenant.email
      assert Repo.get_by(TenantToken, tenant_id: tenant.id)
    end
  end

  describe "change_tenant_password/2" do
    test "returns a tenant changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_tenant_password(%Tenant{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Accounts.change_tenant_password(%Tenant{}, %{
          "password" => "new valid password"
        })

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_tenant_password/3" do
    setup do
      %{tenant: tenant_fixture()}
    end

    test "validates password", %{tenant: tenant} do
      {:error, changeset} =
        Accounts.update_tenant_password(tenant, valid_tenant_password(), %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{tenant: tenant} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_tenant_password(tenant, valid_tenant_password(), %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates current password", %{tenant: tenant} do
      {:error, changeset} =
        Accounts.update_tenant_password(tenant, "invalid", %{password: valid_tenant_password()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{tenant: tenant} do
      {:ok, tenant} =
        Accounts.update_tenant_password(tenant, valid_tenant_password(), %{
          password: "new valid password"
        })

      assert is_nil(tenant.password)
      assert Accounts.get_tenant_by_email_and_password(tenant.email, "new valid password")
    end

    test "deletes all tokens for the given tenant", %{tenant: tenant} do
      _ = Accounts.generate_tenant_session_token(tenant)

      {:ok, _} =
        Accounts.update_tenant_password(tenant, valid_tenant_password(), %{
          password: "new valid password"
        })

      refute Repo.get_by(TenantToken, tenant_id: tenant.id)
    end
  end

  describe "generate_tenant_session_token/1" do
    setup do
      %{tenant: tenant_fixture()}
    end

    test "generates a token", %{tenant: tenant} do
      token = Accounts.generate_tenant_session_token(tenant)
      assert tenant_token = Repo.get_by(TenantToken, token: token)
      assert tenant_token.context == "session"

      # Creating the same token for another tenant should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%TenantToken{
          token: tenant_token.token,
          tenant_id: tenant_fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "get_tenant_by_session_token/1" do
    setup do
      tenant = tenant_fixture()
      token = Accounts.generate_tenant_session_token(tenant)
      %{tenant: tenant, token: token}
    end

    test "returns tenant by token", %{tenant: tenant, token: token} do
      assert session_tenant = Accounts.get_tenant_by_session_token(token)
      assert session_tenant.id == tenant.id
    end

    test "does not return tenant for invalid token" do
      refute Accounts.get_tenant_by_session_token("oops")
    end

    test "does not return tenant for expired token", %{token: token} do
      {1, nil} = Repo.update_all(TenantToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_tenant_by_session_token(token)
    end
  end

  describe "delete_tenant_session_token/1" do
    test "deletes the token" do
      tenant = tenant_fixture()
      token = Accounts.generate_tenant_session_token(tenant)
      assert Accounts.delete_tenant_session_token(token) == :ok
      refute Accounts.get_tenant_by_session_token(token)
    end
  end

  describe "deliver_tenant_confirmation_instructions/2" do
    setup do
      %{tenant: tenant_fixture()}
    end

    test "sends token through notification", %{tenant: tenant} do
      token =
        extract_tenant_token(fn url ->
          Accounts.deliver_tenant_confirmation_instructions(tenant, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert tenant_token = Repo.get_by(TenantToken, token: :crypto.hash(:sha256, token))
      assert tenant_token.tenant_id == tenant.id
      assert tenant_token.sent_to == tenant.email
      assert tenant_token.context == "confirm"
    end
  end

  describe "confirm_tenant/1" do
    setup do
      tenant = tenant_fixture()

      token =
        extract_tenant_token(fn url ->
          Accounts.deliver_tenant_confirmation_instructions(tenant, url)
        end)

      %{tenant: tenant, token: token}
    end

    test "confirms the email with a valid token", %{tenant: tenant, token: token} do
      assert {:ok, confirmed_tenant} = Accounts.confirm_tenant(token)
      assert confirmed_tenant.confirmed_at
      assert confirmed_tenant.confirmed_at != tenant.confirmed_at
      assert Repo.get!(Tenant, tenant.id).confirmed_at
      refute Repo.get_by(TenantToken, tenant_id: tenant.id)
    end

    test "does not confirm with invalid token", %{tenant: tenant} do
      assert Accounts.confirm_tenant("oops") == :error
      refute Repo.get!(Tenant, tenant.id).confirmed_at
      assert Repo.get_by(TenantToken, tenant_id: tenant.id)
    end

    test "does not confirm email if token expired", %{tenant: tenant, token: token} do
      {1, nil} = Repo.update_all(TenantToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.confirm_tenant(token) == :error
      refute Repo.get!(Tenant, tenant.id).confirmed_at
      assert Repo.get_by(TenantToken, tenant_id: tenant.id)
    end
  end

  describe "deliver_tenant_reset_password_instructions/2" do
    setup do
      %{tenant: tenant_fixture()}
    end

    test "sends token through notification", %{tenant: tenant} do
      token =
        extract_tenant_token(fn url ->
          Accounts.deliver_tenant_reset_password_instructions(tenant, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert tenant_token = Repo.get_by(TenantToken, token: :crypto.hash(:sha256, token))
      assert tenant_token.tenant_id == tenant.id
      assert tenant_token.sent_to == tenant.email
      assert tenant_token.context == "reset_password"
    end
  end

  describe "get_tenant_by_reset_password_token/1" do
    setup do
      tenant = tenant_fixture()

      token =
        extract_tenant_token(fn url ->
          Accounts.deliver_tenant_reset_password_instructions(tenant, url)
        end)

      %{tenant: tenant, token: token}
    end

    test "returns the tenant with valid token", %{tenant: %{id: id}, token: token} do
      assert %Tenant{id: ^id} = Accounts.get_tenant_by_reset_password_token(token)
      assert Repo.get_by(TenantToken, tenant_id: id)
    end

    test "does not return the tenant with invalid token", %{tenant: tenant} do
      refute Accounts.get_tenant_by_reset_password_token("oops")
      assert Repo.get_by(TenantToken, tenant_id: tenant.id)
    end

    test "does not return the tenant if token expired", %{tenant: tenant, token: token} do
      {1, nil} = Repo.update_all(TenantToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_tenant_by_reset_password_token(token)
      assert Repo.get_by(TenantToken, tenant_id: tenant.id)
    end
  end

  describe "reset_tenant_password/2" do
    setup do
      %{tenant: tenant_fixture()}
    end

    test "validates password", %{tenant: tenant} do
      {:error, changeset} =
        Accounts.reset_tenant_password(tenant, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{tenant: tenant} do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.reset_tenant_password(tenant, %{password: too_long})
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{tenant: tenant} do
      {:ok, updated_tenant} = Accounts.reset_tenant_password(tenant, %{password: "new valid password"})
      assert is_nil(updated_tenant.password)
      assert Accounts.get_tenant_by_email_and_password(tenant.email, "new valid password")
    end

    test "deletes all tokens for the given tenant", %{tenant: tenant} do
      _ = Accounts.generate_tenant_session_token(tenant)
      {:ok, _} = Accounts.reset_tenant_password(tenant, %{password: "new valid password"})
      refute Repo.get_by(TenantToken, tenant_id: tenant.id)
    end
  end

  describe "inspect/2 for the Tenant module" do
    test "does not include password" do
      refute inspect(%Tenant{password: "123456"}) =~ "password: \"123456\""
    end
  end

  describe "tenants" do
    alias Gojo.Accounts.Tenant

    import Gojo.AccountsFixtures

    @invalid_attrs %{domain: nil, name: nil, subdomain: nil}

    test "list_tenants/0 returns all tenants" do
      tenant = tenant_fixture()
      assert Accounts.list_tenants() == [tenant]
    end

    test "get_tenant!/1 returns the tenant with given id" do
      tenant = tenant_fixture()
      assert Accounts.get_tenant!(tenant.id) == tenant
    end

    test "create_tenant/1 with valid data creates a tenant" do
      valid_attrs = %{domain: "some domain", name: "some name", subdomain: "some subdomain"}

      assert {:ok, %Tenant{} = tenant} = Accounts.create_tenant(valid_attrs)
      assert tenant.domain == "some domain"
      assert tenant.name == "some name"
      assert tenant.subdomain == "some subdomain"
    end

    test "create_tenant/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.create_tenant(@invalid_attrs)
    end

    test "update_tenant/2 with valid data updates the tenant" do
      tenant = tenant_fixture()
      update_attrs = %{domain: "some updated domain", name: "some updated name", subdomain: "some updated subdomain"}

      assert {:ok, %Tenant{} = tenant} = Accounts.update_tenant(tenant, update_attrs)
      assert tenant.domain == "some updated domain"
      assert tenant.name == "some updated name"
      assert tenant.subdomain == "some updated subdomain"
    end

    test "update_tenant/2 with invalid data returns error changeset" do
      tenant = tenant_fixture()
      assert {:error, %Ecto.Changeset{}} = Accounts.update_tenant(tenant, @invalid_attrs)
      assert tenant == Accounts.get_tenant!(tenant.id)
    end

    test "delete_tenant/1 deletes the tenant" do
      tenant = tenant_fixture()
      assert {:ok, %Tenant{}} = Accounts.delete_tenant(tenant)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_tenant!(tenant.id) end
    end

    test "change_tenant/1 returns a tenant changeset" do
      tenant = tenant_fixture()
      assert %Ecto.Changeset{} = Accounts.change_tenant(tenant)
    end
  end
end

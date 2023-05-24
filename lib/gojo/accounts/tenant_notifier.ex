defmodule Gojo.Accounts.TenantNotifier do
  import Swoosh.Email

  alias Gojo.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"Gojo", "contact@example.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(tenant, url) do
    deliver(tenant.email, "Confirmation instructions", """

    ==============================

    Hi #{tenant.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to reset a tenant password.
  """
  def deliver_reset_password_instructions(tenant, url) do
    deliver(tenant.email, "Reset password instructions", """

    ==============================

    Hi #{tenant.email},

    You can reset your password by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to update a tenant email.
  """
  def deliver_update_email_instructions(tenant, url) do
    deliver(tenant.email, "Update email instructions", """

    ==============================

    Hi #{tenant.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end
end

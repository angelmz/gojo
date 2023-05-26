defmodule GojoWeb.Plugs.Get_Subdomain_From_Host_Plug do
  import Plug.Conn

  def init(default), do: default

  def call(conn, _opts) do
    host = conn.host
    subdomain = String.split(host, ".") |> List.first()

    conn
    |> put_private(:subdomain, subdomain)
    |> assign(:subdomain, subdomain)
  end
end
# defp identify_subdomain(conn, _) do
#   [subdomain | _] = conn.host |> String.split(".") |> Enum.reverse
#   assign(conn, :subdomain, subdomain)
# end

defmodule SymphonyElixirWeb.Endpoint do
  @moduledoc """
  Phoenix endpoint for Symphony's optional observability UI and API.
  """

  use Phoenix.Endpoint, otp_app: :symphony_elixir

  socket("/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: {__MODULE__, :session_options, []}]],
    longpoll: false
  )

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)

  plug(:dynamic_session)

  plug(SymphonyElixirWeb.Router)

  @doc false
  def session_options do
    [
      store: :cookie,
      key: "_symphony_elixir_key",
      signing_salt:
        System.get_env("SESSION_SIGNING_SALT") ||
          Application.get_env(:symphony_elixir, :session_signing_salt, "8-bytes-random-default")
    ]
  end

  defp dynamic_session(conn, _opts) do
    opts = Plug.Session.init(session_options())
    Plug.Session.call(conn, opts)
  end
end

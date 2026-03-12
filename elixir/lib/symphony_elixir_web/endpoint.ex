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
  @spec session_options() :: keyword()
  def session_options do
    [
      store: :cookie,
      key: "_symphony_elixir_key",
      signing_salt: Application.get_env(:symphony_elixir, :session_signing_salt, "16-bytes-random-default-salt")
    ]
  end

  defp dynamic_session(conn, _opts) do
    opts =
      case :persistent_term.get({__MODULE__, :session_opts}, nil) do
        nil ->
          init_opts = Plug.Session.init(session_options())
          :persistent_term.put({__MODULE__, :session_opts}, init_opts)
          init_opts

        val ->
          val
      end

    Plug.Session.call(conn, opts)
  end
end

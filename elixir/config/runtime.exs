import Config

live_view_salt = System.get_env("LIVE_VIEW_SIGNING_SALT") || Base.encode64(:crypto.strong_rand_bytes(8))
session_salt = System.get_env("SESSION_SIGNING_SALT") || Base.encode64(:crypto.strong_rand_bytes(8))

config :symphony_elixir, SymphonyElixirWeb.Endpoint, live_view: [signing_salt: live_view_salt]

config :symphony_elixir, :session_signing_salt, session_salt

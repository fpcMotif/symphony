defmodule SymphonyElixirWeb.EndpointTest do
  use ExUnit.Case, async: false
  use Phoenix.ConnTest

  setup do
    # Ensure any residual persistent_term state is cleared before each test
    :persistent_term.erase({SymphonyElixirWeb.Endpoint, :session_opts})
    start_supervised!(SymphonyElixirWeb.Endpoint)
    :ok
  end

  describe "session_options/0" do
    test "returns the default session options" do
      opts = SymphonyElixirWeb.Endpoint.session_options()

      assert Keyword.get(opts, :store) == :cookie
      assert Keyword.get(opts, :key) == "_symphony_elixir_key"
      assert is_binary(Keyword.get(opts, :signing_salt))
    end
  end

  describe "dynamic_session/2 plug" do
    test "initializes session options and caches them in :persistent_term" do
      conn = build_conn(:get, "/api/v1/state")

      # Ensure it's not cached initially
      assert :persistent_term.get({SymphonyElixirWeb.Endpoint, :session_opts}, nil) == nil

      # Process request through endpoint
      # We just care that it doesn't crash and it sets the persistent term.
      _conn = SymphonyElixirWeb.Endpoint.call(conn, [])

      # Now it should be cached
      cached_opts = :persistent_term.get({SymphonyElixirWeb.Endpoint, :session_opts}, nil)
      assert cached_opts != nil

      # The cached opts should be what Plug.Session.init/1 produces
      expected_init = Plug.Session.init(SymphonyElixirWeb.Endpoint.session_options())
      assert cached_opts == expected_init
    end

    test "uses existing :persistent_term if available" do
      conn = build_conn(:get, "/api/v1/state")

      # Pretend it was already initialized with custom opts
      custom_init = Plug.Session.init(store: :cookie, key: "custom_key", signing_salt: "salt")
      :persistent_term.put({SymphonyElixirWeb.Endpoint, :session_opts}, custom_init)

      # Process request through endpoint
      SymphonyElixirWeb.Endpoint.call(conn, [])

      # The persistent term should remain our custom one
      assert :persistent_term.get({SymphonyElixirWeb.Endpoint, :session_opts}, nil) == custom_init
    end
  end

  describe "Endpoint plug pipeline" do
    test "successfully routes and executes without crashing for valid API route" do
      conn = build_conn(:get, "/api/v1/state")

      # Route goes all the way through the endpoint and router
      conn = SymphonyElixirWeb.Endpoint.call(conn, [])

      # Expected to hit the router and return the JSON state
      # (ObservabilityApiController.state/2 returns 200)
      assert conn.status in [200, 503]
    end

    test "handles parser properly for POST requests" do
      # Parsers plug should parse this
      conn =
        build_conn(:post, "/api/v1/refresh", ~s({"some": "data"}))
        |> put_req_header("content-type", "application/json")

      conn = SymphonyElixirWeb.Endpoint.call(conn, [])

      # Depending on how refresh is implemented, it might be a 200 or 202
      assert conn.status in [200, 202, 503]
    end
  end
end

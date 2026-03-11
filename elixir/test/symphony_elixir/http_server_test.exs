defmodule SymphonyElixir.HttpServerTest do
  use SymphonyElixir.TestSupport
  alias SymphonyElixir.HttpServer
  alias SymphonyElixirWeb.Endpoint

  test "child_spec/1 returns valid spec" do
    spec = HttpServer.child_spec(port: 8080)
    assert spec.id == HttpServer
    assert spec.start == {HttpServer, :start_link, [[port: 8080]]}
  end

  test "start_link/1 returns :ignore if no port is provided and no default exists" do
    # Passing port: nil explicitly to trigger the fallback/ignore.
    assert HttpServer.start_link(port: nil) == :ignore
  end

  test "start_link/1 starts the endpoint when a port is provided" do
    # port: 0 asks the OS for a random port
    assert {:ok, _pid} = HttpServer.start_link(port: 0)

    # Verify the bound port is retrievable
    port = HttpServer.bound_port()
    assert is_integer(port)
    assert port > 0

    # Cleanup
    # Stop the endpoint if it was started
    GenServer.stop(Endpoint)
  end

  test "start_link/1 parses various host formats" do
    # Testing host string
    assert {:ok, _} = HttpServer.start_link(port: 0, host: "127.0.0.1")
    GenServer.stop(Endpoint)

    # Testing host tuple
    assert {:ok, _} = HttpServer.start_link(port: 0, host: {127, 0, 0, 1})
    GenServer.stop(Endpoint)

    # Testing localhost
    assert {:ok, _} = HttpServer.start_link(port: 0, host: "localhost")
    GenServer.stop(Endpoint)
  end

  test "bound_port/0 returns nil when endpoint is not started" do
    assert HttpServer.bound_port() == nil
  end

  test "start_link/1 with port: 0 and IPv6 tuple host" do
    assert {:ok, _} = HttpServer.start_link(port: 0, host: {0, 0, 0, 0, 0, 0, 0, 1})
    port = HttpServer.bound_port()
    assert is_integer(port) and port > 0
    GenServer.stop(Endpoint)
  end

  test "start_link/1 ignores negative port" do
    assert HttpServer.start_link(port: -1) == :ignore
  end

  test "start_link/1 ignores string port" do
    assert HttpServer.start_link(port: "8080") == :ignore
  end

  test "start_link/1 accepts snapshot_timeout_ms option" do
    assert {:ok, _} = HttpServer.start_link(port: 0, snapshot_timeout_ms: 5_000)
    GenServer.stop(Endpoint)
  end

  test "child_spec/1 uses correct module for start" do
    spec = HttpServer.child_spec([])
    assert spec.id == HttpServer
    {mod, fun, _args} = spec.start
    assert mod == HttpServer
    assert fun == :start_link
  end
end

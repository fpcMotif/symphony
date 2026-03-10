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
end

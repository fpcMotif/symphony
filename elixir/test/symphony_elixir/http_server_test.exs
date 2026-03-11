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
    try do
      GenServer.stop(Endpoint)
    catch
      :exit, _ -> :ok
    end
  end

  test "start_link/1 parses various host formats" do
    # Testing host string
    assert {:ok, _} = HttpServer.start_link(port: 0, host: "127.0.0.1")

    try do
      GenServer.stop(Endpoint)
    catch
      :exit, _ -> :ok
    end

    # Testing host tuple
    assert {:ok, _} = HttpServer.start_link(port: 0, host: {127, 0, 0, 1})

    try do
      GenServer.stop(Endpoint)
    catch
      :exit, _ -> :ok
    end

    # Testing localhost
    assert {:ok, _} = HttpServer.start_link(port: 0, host: "localhost")

    try do
      GenServer.stop(Endpoint)
    catch
      :exit, _ -> :ok
    end

    # Testing IPv6 tuple
    assert {:ok, _} = HttpServer.start_link(port: 0, host: {0, 0, 0, 0, 0, 0, 0, 1})

    try do
      GenServer.stop(Endpoint)
    catch
      :exit, _ -> :ok
    end
  end

  test "start_link/1 returns :ignore if port is negative" do
    assert HttpServer.start_link(port: -1) == :ignore
  end

  test "start_link/1 handles custom snapshot_timeout_ms" do
    assert {:ok, _pid} = HttpServer.start_link(port: 0, snapshot_timeout_ms: 20_000)

    try do
      GenServer.stop(Endpoint)
    catch
      :exit, _ -> :ok
    end
  end

  test "bound_port/1 returns nil when server is not running" do
    try do
      GenServer.stop(Endpoint)
    catch
      :exit, _ -> :ok
    end

    assert HttpServer.bound_port() == nil
  end

  test "start_link/1 ignores invalid hosts" do
    assert {:error, _} = HttpServer.start_link(port: 0, host: "invalid.hostname.local")
  end

  test "start_link/1 handles atom host and normalize fallback" do
    assert_raise FunctionClauseError, fn ->
      HttpServer.start_link(port: 0, host: :localhost)
    end
  end
end

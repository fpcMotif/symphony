defmodule SymphonyElixirWeb.ObservabilityPubSubTest do
  use ExUnit.Case, async: false

  alias SymphonyElixirWeb.ObservabilityPubSub

  describe "subscribe/0" do
    test "subscribes the current process to the observability topic" do
      assert :ok = ObservabilityPubSub.subscribe()

      # Send a test message directly to verify subscription
      Phoenix.PubSub.broadcast(SymphonyElixir.PubSub, "observability:dashboard", :test_message)
      assert_receive :test_message
    end
  end

  describe "broadcast_update/0" do
    test "broadcasts the :observability_updated message to subscribers" do
      assert :ok = ObservabilityPubSub.subscribe()
      assert :ok = ObservabilityPubSub.broadcast_update()

      assert_receive :observability_updated
    end

    test "returns :ok even if PubSub process is not running" do
      # Since we don't have :meck installed, we can test this by temporarily removing
      # the SymphonyElixir.PubSub registered name, executing the broadcast, and restoring it.

      # Find the PID of the pubsub process
      pubsub_pid = Process.whereis(SymphonyElixir.PubSub)

      if pubsub_pid do
        # Unregister the name to simulate the process being down
        Process.unregister(SymphonyElixir.PubSub)

        # Ensure we restore the registered name afterwards to avoid affecting other tests
        on_exit(fn ->
          try do
            # Wait a brief moment to avoid race conditions and register it back
            Process.sleep(10)

            if Process.alive?(pubsub_pid) do
              Process.register(pubsub_pid, SymphonyElixir.PubSub)
            end
          catch
            # Ignore if already registered or process is dead
            :error, _ -> :ok
          end
        end)
      end

      # broadcast_update should catch the absence of the registered name and return :ok without crashing
      assert :ok = ObservabilityPubSub.broadcast_update()
    end
  end
end

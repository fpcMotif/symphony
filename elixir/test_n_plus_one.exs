defmodule WorkspaceBenchmark do
  def run do
    # Simulating the issue context
    identifier = "TEST-123"
    worker_hosts = Enum.map(1..100, &"host-#{&1}")

    # The original implementation
    {time_orig, _} = :timer.tc(fn ->
      Enum.each(worker_hosts, fn host ->
        # Simulate network delay/work
        Process.sleep(5)
      end)
    end)

    # The optimized implementation
    {time_opt, _} = :timer.tc(fn ->
      worker_hosts
      |> Task.async_stream(fn host ->
        # Simulate network delay/work
        Process.sleep(5)
      end, max_concurrency: 10, timeout: 5000)
      |> Stream.run()
    end)

    IO.puts("Original (Enum.each): #{time_orig / 1000} ms")
    IO.puts("Optimized (Task.async_stream): #{time_opt / 1000} ms")
    IO.puts("Improvement: #{Float.round(((time_orig - time_opt) / time_orig) * 100, 2)}%")
  end
end

WorkspaceBenchmark.run()

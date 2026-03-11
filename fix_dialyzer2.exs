defmodule FixDialyzer2 do
  def run do
    path = "lib/symphony_elixir/http_server.ex"
    content = File.read!(path)

    # 85: defp normalize_host(host), do: to_string(host)
    # The warning is about this pattern never matching. It seems the spec for normalize_host might mean `host` is only binary or IP tuple.
    # It has `defp normalize_host(host), do: to_string(host)` which dialszer complains about because host is already covered.
    content = String.replace(content, "defp normalize_host(host), do: to_string(host)", "")

    File.write!(path, content)
  end
end

FixDialyzer2.run()

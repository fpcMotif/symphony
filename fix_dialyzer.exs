defmodule FixDialyzer do
  def run do
    path = "lib/symphony_elixir/http_server.ex"
    content = File.read!(path)

    # Dialyzer complains about variable_host pattern being fully covered by previous clauses
    # We should search for where `variable_host` is used in http_server.ex
    File.write!(path, content)
  end
end

FixDialyzer.run()

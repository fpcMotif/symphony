defmodule FixTestHelpers3 do
  def run do
    path = "lib/symphony_elixir/orchestrator.ex"
    content = File.read!(path)

    # In revalidate_issue_for_dispatch fallback clause
    content = String.replace(
      content,
      "defp revalidate_issue_for_dispatch(issue, _issue_fetcher, _terminal_states), do: {:ok, issue}",
      "defp revalidate_issue_for_dispatch(issue, _issue_fetcher, _active_states, _terminal_states), do: {:ok, issue}"
    )

    File.write!(path, content)
  end
end

FixTestHelpers3.run()

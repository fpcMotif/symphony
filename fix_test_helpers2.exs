defmodule FixTestHelpers2 do
  def run do
    path = "lib/symphony_elixir/orchestrator.ex"
    content = File.read!(path)

    # In revalidate_issue_for_dispatch_for_test
    content = String.replace(
      content,
      "revalidate_issue_for_dispatch(issue, issue_fetcher, terminal_state_set())",
      "revalidate_issue_for_dispatch(issue, issue_fetcher, active_state_set(), terminal_state_set())"
    )

    File.write!(path, content)
  end
end

FixTestHelpers2.run()

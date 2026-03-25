#### Context
🎯 **What:** The `render/1` function in `DashboardLive` was over 150 lines long, containing a monolithic HEEx template that handled the header, error states, metric grids, rate limits, running sessions, and retry queues.
💡 **Why:** Large render functions in LiveView can be difficult to read, maintain, and test. By splitting the main `render/1` function into smaller, well-named private function components (`header/1`, `error_card/1`, `metric_grid/1`, `rate_limits/1`, `running_sessions/1`, `retry_queue/1`), the code becomes modular, easier to scan, and follows established Phoenix LiveView best practices for maintainability.

#### TL;DR
Refactored the monolithic `render/1` function in `SymphonyElixirWeb.DashboardLive` into smaller, focused HEEx components.

#### Summary
- Extracted `<header>` into `header/1`.
- Extracted error state section into `error_card/1`.
- Extracted metric grid section into `metric_grid/1`.
- Extracted rate limits section into `rate_limits/1`.
- Extracted running sessions table into `running_sessions/1`.
- Extracted retry queue table into `retry_queue/1`.
- Updated `render/1` to compose these new components, passing necessary `@payload` and `@now` assigns.

#### Alternatives
- Left the function as is, which was flagged as a code health issue.
- Extracted the components into a completely separate module (e.g., `DashboardComponents`), but since these components are highly specific to this live view and rely on its other private helpers (like `format_runtime_seconds`), keeping them as private function components (`defp`) within `DashboardLive` is the safer and simpler alternative.

#### Test Plan
✅ **Verification:**
- Ran `mix format` and `mix credo --strict` to ensure code style compliance.
- Ran the full test suite (`mix test`) which passed successfully.
- Specifically ran the integration tests for the dashboard (`test/symphony_elixir/dashboard_live_test.exs`, `test/symphony_elixir/status_dashboard_snapshot_test.exs`, `test/symphony_elixir/status_dashboard_test.exs`) to guarantee that HTML rendering remains structurally sound and that assigns are properly forwarded to the extracted components.

✨ **Result:** The code health issue is resolved, making the dashboard significantly easier to read and modify without altering any underlying behavior.

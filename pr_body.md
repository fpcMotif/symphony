#### Context
The `render/1` function in `SymphonyElixirWeb.DashboardLive` was an overly long function containing the entire dashboard layout, metrics grid, running sessions table, and retry queue table in a single HEEx template. Breaking down this very long function improves readability and makes the template easier to maintain.

#### TL;DR
Refactored the dashboard `render/1` function by extracting distinct sections into private function components.

#### Summary
- Extracted the hero card section into a `<.dashboard_header />` component.
- Extracted the error section into an `<.error_state />` component.
- Extracted the metrics grid into a `<.metrics_grid />` component.
- Extracted the rate limits section into a `<.rate_limits />` component.
- Extracted the running sessions section into a `<.running_sessions />` component.
- Extracted the retry queue section into a `<.retry_queue />` component.
- Updated `render/1` to invoke these extracted components, vastly reducing its length and complexity.

#### Alternatives
An alternative would have been to leave the file as is, but that would make future modifications harder and harder to navigate. We could have also extracted these into entirely separate modules, but keeping them as private function components within the same module is the standard Phoenix approach and keeps the file cohesive.

#### Test Plan
- Run `mix format` to verify formatting.
- Run `mix test` to ensure the application still functions correctly.
- Tests pass as expected, and manual observation of the dashboard structure shows it should be identical.

#### Context
This PR addresses a code health issue in `elixir/lib/symphony_elixir/codex/app_server.ex`.

#### TL;DR
Refactored the long `run_turn` function to extract case statement logic into private helper functions.

#### Summary
🎯 **What:** The code health issue addressed is that the `run_turn` function was too long and complex, primarily due to the inline handling of the `start_turn` success and error states. This has been resolved by introducing two new private helper functions: `handle_start_turn_success` and `handle_start_turn_error`.
💡 **Why:** Breaking down this function improves readability and makes the logic easier to follow and unit test.
✅ **Verification:** I ran the test suite (`mix test`), code formatter (`mix format`), and static analysis (`mix credo --strict`). All tools passed cleanly, verifying that no behavior was broken or degraded by the refactor.
✨ **Result:** A more concise and maintainable `run_turn` function that clearly communicates its intent.

#### Alternatives
Instead of separating into two individual success and error handlers, the entire case statement could have been extracted to a `handle_start_turn_result` helper, but the chosen approach is more direct.

#### Test Plan
The existing suite covering `SymphonyElixir.Codex.AppServer` asserts this logic fully. `mix test` successfully passes.

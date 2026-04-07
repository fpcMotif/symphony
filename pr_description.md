#### Context
Refactoring nested conditionals often requires pulling out smaller helper functions. It's manageable but requires careful verification of variables in scope. The nested `receive do ... case reason do` block in `elixir/lib/symphony_elixir/cli.ex` was deeply nested.

#### TL;DR
Flattened the nested `receive do ... case reason do` block using Elixir pattern matching.

#### Summary
🎯 **What:** Flattened a nested `case` statement within a `receive` block into idiomatic direct pattern matches inside `receive`.
💡 **Why:** This reduces nesting and makes the code slightly more concise and easier to read.
✅ **Verification:** Ran `mix format` and `mix test` successfully across the whole project, specifically including `test/symphony_elixir/cli_test.exs`. No behaviour changes were introduced.
✨ **Result:** Improved maintainability and reduced cognitive load for readers by removing one level of nesting.

#### Alternatives
Extracting the inner block into a private helper function.

#### Test Plan
Tested via the project `mix test` suite. Tested specifically the cli suite: `mix test test/symphony_elixir/cli_test.exs`.

gh pr edit fix-app-server-handle-incoming --body '#### Context

The `handle_incoming` function and related `receive_loop` in the AppServer passed 5+ arguments down the stack, making the signature brittle and hard to read.

#### TL;DR

*Refactored AppServer handle_incoming and receive_loop to use a unified state map, improving maintainability.*

#### Summary

- Grouped `port`, `on_message`, `timeout_ms`, etc. into a `state` map
- Updated `handle_incoming` and `receive_loop` to accept `state`
- Cleaned up pattern matching in helper functions
- Reduced function arity across the AppServer codebase

#### Alternatives

- No action. This preserves a verbose and rigid signature chain that is harder to test and extend.

#### Test Plan

- [x] `make -C elixir all`
- [x] `cd elixir && mix compile --warnings-as-errors`
- [x] `cd elixir && mix test`'

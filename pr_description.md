#### Context
Replaces a fake TODO string with OPEN in config_test.exs to prevent false positives in TODO scanners.

#### TL;DR
Replaces a test string from TODO to OPEN in ConfigTest.

#### Summary
- Replaces `"TODO"` with `"OPEN"` in config tests
- Replaces `"todo"` with `"open"` in config tests
- Replaces `:todo` with `:open` in config tests

#### Alternatives
- Use another state name like "Backlog" instead of "OPEN".

#### Test Plan
- [x] Run `mix test`

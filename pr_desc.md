#### Context

The original function was extremely long and mixed multiple concerns. Extracting logical UI sections into helpers improves maintainability.

#### TL;DR

*Simplified format_snapshot_content by extracting formatting logic into private helper functions.*

#### Summary

- Extracted format_dashboard_header.
- Extracted format_running_section.
- Extracted format_backoff_section.
- format_snapshot_content is now concise and delegates rendering concerns appropriately.

#### Alternatives

- Leave the function as is. This was rejected because the original function is too long, making it hard to read and modify safely.

#### Test Plan

- [x] `make -C elixir all`
- [x] Tested the local formatting logic manually by running `mix format` and `mix credo --strict`.
- [x] Confirmed the test suite still passes successfully with `mix test`.

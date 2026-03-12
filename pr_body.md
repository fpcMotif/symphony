#### Context

The render function in SymphonyElixirWeb.DashboardLive was too large, making it hard to read and maintain. Extracting sections into small components simplifies the template.

#### TL;DR

*Simplified DashboardLive render block by extracting UI sections into smaller, functional HEEx components.*

#### Summary

- Extracted hero header into a private functional component
- Extracted error card into a private functional component
- Extracted metric grid into a private functional component
- Extracted rate limits section into a private functional component
- Extracted running sessions section into a private functional component
- Extracted retry queue section into a private functional component
- Refactored render/1 to use these new components

#### Alternatives

- Leave the template monolithic (rejected: harder to read)

#### Test Plan

- [x] `make -C elixir all`
- [x] Verified full test suite runs successfully via `mix test`

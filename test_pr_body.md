#### Context

Verify that signing_salt is securely generated to prevent Cross-Site WebSocket Hijacking.

#### TL;DR

*Confirmed signing_salt is properly derived at compile time.*

#### Summary

- Verified signing_salt uses System.get_env
- No code modifications were necessary
- This ensures session integrity

#### Alternatives

- Setting signing_salt via MFA was attempted but Plug.Session strictly requires a binary string.

#### Test Plan

- [x] `make -C elixir all`
- [x] `mix test` passes without errors

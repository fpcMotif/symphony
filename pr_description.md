#### Context

Passing unsanitized strings directly to `String.to_atom/1` could crash the Erlang VM by exceeding the maximum atom table limit, leading to an application-level Denial of Service.

#### TL;DR

*Replaced `String.to_atom` with `String.to_existing_atom` to eliminate the VM-wide memory crash risk from untrusted adapter strings.*

#### Summary

- Changed dynamic tracker module creation to use `String.to_existing_atom/1`.
- Wrapped atom creation in a `try/rescue` block to catch and raise a descriptive error if the module is invalid.
- Added test coverage in `tracker_contract_test.exs` to ensure invalid modules throw `ArgumentError`.

#### Alternatives

- Maintained a hard-coded allowlist. But `String.to_existing_atom/1` combined with `try/rescue` gracefully secures dynamic module names without adding maintenance overhead.

#### Test Plan

- [x] `make -C elixir all`
- [x] Run test suite to verify no regressions: `mix test`

🎯 **What:** Fixed an atom exhaustion Denial of Service vulnerability in `tracker.ex`.
⚠️ **Risk:** Exploiting this could crash the entire Erlang VM by filling the atom table.
🛡️ **Solution:** Replaced `String.to_atom/1` with `String.to_existing_atom/1` inside a `try/rescue` block.

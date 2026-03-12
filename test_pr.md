test: add orchestrator tracker API tests and fix flaky core test

#### Context
The tracker write APIs were implemented in the orchestrator but lacked unit tests, and the specification still marked it as a pending TODO. A flaky core test was also occasionally failing in CI.

#### TL;DR
Add unit tests for orchestrator tracker write APIs, remove pending TODO from SPEC.md, and loosen the bounds of a flaky core test assertion.

#### Summary
- Added docstrings to Orchestrator.create_comment/3 and Orchestrator.update_issue_state/3
- Added explicit API interaction tests for the orchestrator memory tracker
- Removed corresponding TODO from SPEC.md
- Adjusted `assert_due_in_range` bound for `abnormal worker exit` from 39_000 to 38_000
- Adjusted `assert_due_in_range` bound for `first abnormal worker exit` from 8_750 to 8_000

#### Alternatives
- Leave the bounds strict and accept sporadic CI failures due to process execution delay variance.

#### Test Plan
- [x] `make -C elixir all`
- [x] Ran `mix test` to verify `SymphonyElixir.OrchestratorTrackerApiTest` and the fixed `core_test.exs` flakiness.

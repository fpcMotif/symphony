#### Context
The WorkflowStore module was missing robust test coverage for its filesystem polling and startup paths.
#### TL;DR
Added tests for WorkflowStore.start_link/0 and automated filesystem polling mechanism.
#### Summary
- Added a new ExUnit test for WorkflowStore.start_link/0.
- Implemented an integration test that creates a temporary configuration file, advances its mtime, and verifies that the automated polling loop detects the change.
- Both tests ensure that spawned processes are correctly stopped after assertions to prevent state bleeding into other test suites.
#### Alternatives
- Leave the polling mechanism untested, which was causing lower test suite confidence and potential future regressions.
#### Test Plan
- [x] `make -C elixir all`
- [x] Run `mix test test/symphony_elixir/workflow_store_test.exs` locally.

#### Context
Testing Phoenix endpoints directly without hitting specific routes requires specialized ConnCase setup which can be boilerplate-heavy. Currently, `SymphonyElixirWeb.Endpoint` has untested endpoint configuration for session options and plug pipeline execution.

#### TL;DR
Added a dedicated ExUnit test file for `SymphonyElixirWeb.Endpoint`.

#### Summary
Created `elixir/test/symphony_elixir_web/endpoint_test.exs` to test:
- `session_options/0` output structure.
- `dynamic_session/2` caching via `:persistent_term`.
- Execution flow of `Conn` through the endpoint pipeline for API endpoints.

#### Alternatives
- Using full end-to-end LiveView/Feature tests to implicitly test the Endpoint. (Rejected: we wanted targeted unit/integration tests for the endpoint itself).

#### Test Plan
The newly added ExUnit test covers these flows.

---
🎯 **What:** The testing gap addressed is the lack of test coverage around the Phoenix Endpoint initialization and dynamic session caching plug.
📊 **Coverage:** What scenarios are now tested include default session option generation, `persistent_term` usage for dynamic session optimization, and the successful routing of standard API requests through the endpoint's plug pipeline.
✨ **Result:** Increased test coverage and validation of critical web infrastructure configuration.

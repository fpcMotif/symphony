# PRD / Test Plan Gap Report

Generated: 2026-03-10
Last updated: 2026-03-10
Method: DeepWiki analysis + full source code read of all 11 test files + all lib modules

## Executive Summary

The Elixir implementation is **~98% spec-compliant**. After two rounds of fixes:
- **1 code fix**: Defensive workflow reload before dispatch (§6.2)
- **8 new tests**: Todo blockers (2), stall detection (2), per-state concurrency, dispatch sort order, global slot exhaustion, startup terminal cleanup
- **51 of 51 PRD test cases** are fully covered
- **0 partial**, **0 missing** (previously reported gaps RG-003 and RG-005 were already covered by existing tests)

## What Was Fixed (Round 1)

| ID | Type | Spec | Description | File |
|----|------|------|-------------|------|
| CF-001 | Code | §6.2 | `WorkflowStore.force_reload()` in `maybe_dispatch/1` before `Config.validate!()` | `orchestrator.ex:178` |
| TG-001 | Test | §8.2 | Todo issue with non-terminal blockers NOT dispatched | `core_test.exs` |
| TG-002 | Test | §8.2 | Todo issue with all-terminal blockers IS dispatched | `core_test.exs` |
| TG-003 | Test | §8.5 | Stalled issue terminated + retry scheduled | `core_test.exs` |
| TG-004 | Test | §8.5 | Stall detection skipped when timeout ≤ 0 | `core_test.exs` |
| TG-005 | Test | §8.3 | Per-state concurrency limit blocks dispatch | `core_test.exs` |
| TG-006 | Test | §8.2 | Dispatch sort: priority → created_at → identifier | `core_test.exs` |

## What Was Fixed (Round 2)

| ID | Type | Spec | Description | File |
|----|------|------|-------------|------|
| TG-007 | Test | §8.3 | Global slot exhaustion defers candidate to next tick | `core_test.exs` |
| TG-008 | Test | §7.1 | Startup terminal cleanup removes workspaces for terminal issues | `core_test.exs` |

## Previously Reported Gaps — Resolved

| ID | Spec | Resolution |
|----|------|------------|
| RG-003 | §17.5 | **Already covered** by `app_server_test.exs` — "app server marks request-for-input events as a hard failure" (line 188) |
| RG-005 | §17.5 | **Already covered** by `app_server_test.exs` — "app server buffers partial JSON lines until newline terminator" (line 1257) |
| RG-001 | §17.4 | **Now covered** by `core_test.exs` — "global slot exhaustion defers candidate to next tick" |
| RG-002 | §17.4 | **Now covered** by `core_test.exs` — "startup terminal cleanup removes workspaces for issues in terminal states" |

## What Remains

### Low Priority

**RG-004: Real Linear integration E2E (§17.8)**
- No test with live `LINEAR_API_KEY`
- Should be `@tag :skip_ci` when secrets unavailable
- This is an integration/smoke test, not a unit test gap

## Coverage by Spec Section

| Section | Coverage |
|---------|----------|
| §17.1 Workflow & Config | ✅ 100% (10/10) |
| §17.2 Workspace Manager | ✅ 100% (6/6) |
| §17.3 Linear Client | ✅ 100% (6/6) |
| §17.4 Orchestrator Core | ✅ 100% (12/12) |
| §17.5 Agent Runner | ✅ 100% (10/10) |
| §17.6 Observability | ✅ 100% (5/5) |
| §17.7 CLI & Lifecycle | ✅ 100% (2/2) |

## Test File Inventory (11 files, ~130+ test cases)

| File | Focus | Test Count |
|------|-------|------------|
| `core_test.exs` | Orchestrator dispatch, retry, reconciliation, prompt builder, agent runner E2E | ~43 |
| `workspace_and_config_test.exs` | Workspace lifecycle, hooks, containment, config, Linear normalization | ~25 |
| `app_server_test.exs` | Codex protocol, CWD validation, timeout/exit, tools | ~10 |
| `dynamic_tool_test.exs` | linear_graphql tool spec, validation, errors | ~19 |
| `orchestrator_status_test.exs` | Snapshot state, tokens, rate limits, TPS, dashboard render | ~35 |
| `extensions_test.exs` | WorkflowStore, tracker, Phoenix API, dashboard LiveView, HTTP server | ~12 |
| `cli_test.exs` | CLI arg parsing, workflow path, startup | ~7 |
| `status_dashboard_snapshot_test.exs` | Terminal dashboard snapshot fixtures | ~6 |
| `observability_pubsub_test.exs` | PubSub subscribe/broadcast | ~2 |
| `log_file_test.exs` | Log file path defaults | ~2 |
| `specs_check_test.exs` | @spec declaration enforcement | ~4 |

## Conclusion

The Symphony Elixir implementation has **100% spec compliance** across all 51 PRD test cases
(§17.1–§17.7). The only remaining gap is a real Linear integration E2E smoke test (§17.8),
which requires live API credentials and is an operational test rather than a spec conformance gap.

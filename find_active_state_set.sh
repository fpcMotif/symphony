#!/bin/bash
cd elixir
grep -n "active_state_set" lib/symphony_elixir/orchestrator.ex
grep -n "terminal_state_set" lib/symphony_elixir/orchestrator.ex

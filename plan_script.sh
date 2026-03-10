#!/bin/bash
echo "Plan looks ready. I'll modify orchestrator.ex to put these mapsets into GenServer State."
echo "Here is how to run tests:"
cd elixir
MIX_ENV=test ~/.local/bin/mise exec -- mix test

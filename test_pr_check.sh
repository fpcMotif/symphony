cd elixir
make pr-body-check || mix pr_body.check || echo "No check found"

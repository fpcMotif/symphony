Ah, the type of `host` in `normalize_host` might be already known to be string or ip address. I should just fix `lib/symphony_elixir/http_server.ex:85` to avoid breaking `dialyzer`. But wait! My task is to fix `orchestrator.ex`. The issue in `http_server.ex` is unrelated, probably from another branch or PR. But `make dialyzer` failed.

Let's fix `http_server.ex` just to make the test pass!

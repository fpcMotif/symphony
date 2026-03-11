defmodule SymphonyElixir.StaticAssetControllerTest do
  use SymphonyElixir.TestSupport

  import Phoenix.ConnTest

  @endpoint SymphonyElixirWeb.Endpoint

  test "serves dashboard static assets with cache headers" do
    start_test_endpoint(
      orchestrator: Module.concat(__MODULE__, :AssetOrchestrator),
      snapshot_timeout_ms: 50
    )

    assert_asset("/dashboard.css", "text/css", [":root", "dashboard-shell"])

    assert_asset("/vendor/phoenix_html/phoenix_html.js", "application/javascript", [
      "phoenix.link.click"
    ])

    assert_asset("/vendor/phoenix/phoenix.js", "application/javascript", ["var Phoenix"])

    assert_asset("/vendor/phoenix_live_view/phoenix_live_view.js", "application/javascript", [
      "LiveView"
    ])
  end

  test "returns 404 for missing asset path" do
    start_test_endpoint(
      orchestrator: Module.concat(__MODULE__, :MissingAssetOrchestrator),
      snapshot_timeout_ms: 50
    )

    conn = get(build_conn(), "/vendor/phoenix/missing.js")

    assert response(conn, 404) == "Not Found"
  end

  defp assert_asset(path, expected_content_type, required_snippets) do
    conn = get(build_conn(), path)

    assert conn.status == 200
    assert [content_type | _] = get_resp_header(conn, "content-type")
    assert String.starts_with?(content_type, expected_content_type)
    assert get_resp_header(conn, "cache-control") == ["public, max-age=31536000"]

    body = response(conn, 200)
    assert String.trim(body) != ""

    Enum.each(required_snippets, fn snippet ->
      assert body =~ snippet
    end)
  end

  defp start_test_endpoint(overrides) do
    endpoint_config =
      :symphony_elixir
      |> Application.get_env(SymphonyElixirWeb.Endpoint, [])
      |> Keyword.merge(server: false, secret_key_base: String.duplicate("s", 64))
      |> Keyword.merge(overrides)

    Application.put_env(:symphony_elixir, SymphonyElixirWeb.Endpoint, endpoint_config)
    start_supervised!({SymphonyElixirWeb.Endpoint, []})
  end
end

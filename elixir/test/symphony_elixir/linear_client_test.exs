defmodule SymphonyElixir.LinearClientTest do
  use SymphonyElixir.TestSupport

  alias SymphonyElixir.Linear.Client

  test "fetch_candidate_issues/0 resolves assignee me through viewer id" do
    responses = [
      %{status: 200, body: %{"data" => %{"viewer" => %{"id" => "viewer-1"}}}},
      %{status: 200, body: issues_payload([issue_node("issue-1", "viewer-1")])}
    ]

    with_stubbed_linear(responses, [tracker_assignee: "me"], fn ->
      assert {:ok, [%{id: "issue-1", assigned_to_worker: true, assignee_id: "viewer-1"}]} =
               Client.fetch_candidate_issues()

      assert_receive {:stub_request, %{json: %{"query" => viewer_query}}}
      assert viewer_query =~ "query SymphonyLinearViewer"

      assert_receive {:stub_request, %{json: %{"query" => issues_query}}}
      assert issues_query =~ "query SymphonyLinearPoll"
    end)
  end

  test "fetch_issue_states_by_ids/1 returns missing viewer identity when viewer payload is malformed" do
    responses = [
      %{status: 200, body: %{"data" => %{"viewer" => %{}}}}
    ]

    with_stubbed_linear(responses, [tracker_assignee: "me"], fn ->
      assert {:error, :missing_linear_viewer_identity} =
               Client.fetch_issue_states_by_ids(["issue-1"])
    end)
  end

  test "fetch_issue_states_by_ids/1 propagates viewer lookup request failures" do
    responses = [
      %{status: 500, body: %{"errors" => [%{"message" => "viewer failed"}]}}
    ]

    with_stubbed_linear(responses, [tracker_assignee: "me"], fn ->
      assert {:error, {:linear_api_status, 500}} =
               Client.fetch_issue_states_by_ids(["issue-1"])
    end)
  end

  test "next_page_cursor_for_test/1 returns the next cursor when page info is complete" do
    assert {:ok, "cursor-1"} =
             Client.next_page_cursor_for_test(%{has_next_page: true, end_cursor: "cursor-1"})
  end

  test "next_page_cursor_for_test/1 errors when has_next_page is true without end_cursor" do
    assert {:error, :linear_missing_end_cursor} =
             Client.next_page_cursor_for_test(%{has_next_page: true})
  end

  test "next_page_cursor_for_test/1 returns done when there is no next page" do
    assert :done = Client.next_page_cursor_for_test(%{has_next_page: false, end_cursor: nil})
  end

  test "fetch_issue_states_by_ids/1 returns graphql errors payloads" do
    responses = [
      %{status: 200, body: %{"errors" => [%{"message" => "bad query"}]}}
    ]

    with_stubbed_linear(responses, fn ->
      assert {:error, {:linear_graphql_errors, [%{"message" => "bad query"}]}} =
               Client.fetch_issue_states_by_ids(["issue-1"])
    end)
  end

  test "fetch_issue_states_by_ids/1 returns unknown payload errors for unexpected responses" do
    responses = [
      %{status: 200, body: %{"data" => %{"viewer" => %{"id" => "unrelated"}}}}
    ]

    with_stubbed_linear(responses, fn ->
      assert {:error, :linear_unknown_payload} =
               Client.fetch_issue_states_by_ids(["issue-1"])
    end)
  end

  defp with_stubbed_linear(responses, workflow_overrides \\ [], fun) do
    {server_pid, port} = start_stub_server(responses)

    try do
      write_workflow_file!(
        Workflow.workflow_file_path(),
        Keyword.merge([tracker_endpoint: "http://127.0.0.1:#{port}/graphql"], workflow_overrides)
      )

      fun.()
    after
      Process.exit(server_pid, :normal)
    end
  end

  defp start_stub_server(responses) do
    test_pid = self()

    {:ok, listen_socket} =
      :gen_tcp.listen(0, [:binary, packet: :raw, active: false, reuseaddr: true, ip: {127, 0, 0, 1}])

    {:ok, {_ip, port}} = :inet.sockname(listen_socket)

    server_pid =
      spawn_link(fn ->
        Enum.each(responses, fn response ->
          {:ok, socket} = :gen_tcp.accept(listen_socket)
          request = recv_http_request(socket)
          send(test_pid, {:stub_request, request})
          send_http_response(socket, response)
          :gen_tcp.close(socket)
        end)

        :gen_tcp.close(listen_socket)
      end)

    {server_pid, port}
  end

  defp recv_http_request(socket) do
    {header_blob, body_prefix} = recv_until_headers(socket, "")

    content_length =
      case Regex.run(~r/content-length:\s*(\d+)/i, header_blob, capture: :all_but_first) do
        [value] -> String.to_integer(value)
        _ -> 0
      end

    body =
      if byte_size(body_prefix) >= content_length do
        binary_part(body_prefix, 0, content_length)
      else
        body_prefix <> recv_exact(socket, content_length - byte_size(body_prefix), "")
      end

    json =
      case Jason.decode(body) do
        {:ok, payload} -> payload
        _ -> nil
      end

    %{headers: header_blob, body: body, json: json}
  end

  defp recv_until_headers(socket, acc) do
    case :binary.match(acc, "\r\n\r\n") do
      {index, 4} ->
        {binary_part(acc, 0, index + 4), binary_part(acc, index + 4, byte_size(acc) - index - 4)}

      :nomatch ->
        {:ok, chunk} = :gen_tcp.recv(socket, 0)
        recv_until_headers(socket, acc <> chunk)
    end
  end

  defp recv_exact(_socket, 0, acc), do: acc

  defp recv_exact(socket, remaining, acc) do
    {:ok, chunk} = :gen_tcp.recv(socket, 0)
    chunk_size = byte_size(chunk)

    cond do
      chunk_size == remaining ->
        acc <> chunk

      chunk_size < remaining ->
        recv_exact(socket, remaining - chunk_size, acc <> chunk)

      true ->
        acc <> binary_part(chunk, 0, remaining)
    end
  end

  defp send_http_response(socket, %{status: status, body: body}) do
    encoded_body = Jason.encode!(body)

    response = [
      "HTTP/1.1 ",
      Integer.to_string(status),
      " ",
      reason_phrase(status),
      "\r\n",
      "content-type: application/json\r\n",
      "content-length: ",
      Integer.to_string(byte_size(encoded_body)),
      "\r\n",
      "connection: close\r\n\r\n",
      encoded_body
    ]

    :gen_tcp.send(socket, response)
  end

  defp reason_phrase(200), do: "OK"
  defp reason_phrase(500), do: "Internal Server Error"
  defp reason_phrase(_status), do: "Unknown"

  defp issues_payload(nodes) do
    %{
      "data" => %{
        "issues" => %{
          "nodes" => nodes,
          "pageInfo" => %{"hasNextPage" => false, "endCursor" => nil}
        }
      }
    }
  end

  defp issue_node(id, assignee_id) do
    %{
      "id" => id,
      "identifier" => "MT-1",
      "title" => "Issue #{id}",
      "description" => "desc",
      "priority" => 2,
      "state" => %{"name" => "Todo"},
      "branchName" => "branch-#{id}",
      "url" => "https://example.test/issues/#{id}",
      "assignee" => %{"id" => assignee_id},
      "labels" => %{"nodes" => []},
      "inverseRelations" => %{"nodes" => []},
      "createdAt" => "2026-01-01T00:00:00Z",
      "updatedAt" => "2026-01-01T00:00:00Z"
    }
  end
end

defmodule SymphonyElixir.Linear.ClientTest do
  use SymphonyElixir.TestSupport

  describe "normalize_issue_for_test/1" do
    test "normalizes a complete Linear API issue map to an Issue struct" do
      raw = %{
        "id" => "issue-1",
        "identifier" => "PRJ-100",
        "title" => "Fix the bug",
        "description" => "There is a bug in prod",
        "priority" => 2,
        "state" => %{"name" => "In Progress"},
        "branchName" => "prj-100-fix-the-bug",
        "url" => "https://linear.app/prj/issue/PRJ-100",
        "assignee" => %{"id" => "user-abc"},
        "labels" => %{"nodes" => [%{"name" => "Bug"}, %{"name" => "Backend"}]},
        "inverseRelations" => %{"nodes" => []},
        "createdAt" => "2025-06-01T12:00:00.000Z",
        "updatedAt" => "2025-06-02T14:30:00.000Z"
      }

      issue = Client.normalize_issue_for_test(raw)

      assert %Issue{} = issue
      assert issue.id == "issue-1"
      assert issue.identifier == "PRJ-100"
      assert issue.title == "Fix the bug"
      assert issue.description == "There is a bug in prod"
      assert issue.priority == 2
      assert issue.state == "In Progress"
      assert issue.branch_name == "prj-100-fix-the-bug"
      assert issue.url == "https://linear.app/prj/issue/PRJ-100"
      assert issue.assignee_id == "user-abc"
      assert issue.labels == ["bug", "backend"]
      assert issue.blocked_by == []
      assert issue.assigned_to_worker == true
      assert %DateTime{} = issue.created_at
      assert %DateTime{} = issue.updated_at
    end

    test "returns nil for non-map input" do
      assert Client.normalize_issue_for_test("not a map") == nil
    end

    test "handles missing optional fields gracefully" do
      raw = %{
        "id" => "issue-2",
        "identifier" => "PRJ-101",
        "title" => "Minimal issue",
        "description" => nil,
        "priority" => nil,
        "state" => %{"name" => "Todo"},
        "branchName" => nil,
        "url" => nil,
        "assignee" => nil,
        "labels" => %{"nodes" => []},
        "inverseRelations" => %{"nodes" => []},
        "createdAt" => nil,
        "updatedAt" => nil
      }

      issue = Client.normalize_issue_for_test(raw)

      assert issue.id == "issue-2"
      assert issue.description == nil
      assert issue.priority == nil
      assert issue.branch_name == nil
      assert issue.assignee_id == nil
      assert issue.labels == []
      assert issue.created_at == nil
      assert issue.updated_at == nil
    end
  end

  describe "normalize_issue_for_test/2 with assignee filtering" do
    test "marks issue as assigned_to_worker when assignee matches filter" do
      raw = %{
        "id" => "issue-3",
        "identifier" => "PRJ-102",
        "title" => "Assigned issue",
        "description" => nil,
        "priority" => 1,
        "state" => %{"name" => "Todo"},
        "branchName" => nil,
        "url" => nil,
        "assignee" => %{"id" => "user-xyz"},
        "labels" => %{"nodes" => []},
        "inverseRelations" => %{"nodes" => []},
        "createdAt" => nil,
        "updatedAt" => nil
      }

      issue = Client.normalize_issue_for_test(raw, "user-xyz")
      assert issue.assigned_to_worker == true
    end

    test "marks issue as not assigned_to_worker when assignee does not match" do
      raw = %{
        "id" => "issue-4",
        "identifier" => "PRJ-103",
        "title" => "Unassigned issue",
        "description" => nil,
        "priority" => 1,
        "state" => %{"name" => "Todo"},
        "branchName" => nil,
        "url" => nil,
        "assignee" => %{"id" => "user-other"},
        "labels" => %{"nodes" => []},
        "inverseRelations" => %{"nodes" => []},
        "createdAt" => nil,
        "updatedAt" => nil
      }

      issue = Client.normalize_issue_for_test(raw, "user-xyz")
      assert issue.assigned_to_worker == false
    end

    test "marks issue as not assigned_to_worker when no assignee and filter is set" do
      raw = %{
        "id" => "issue-5",
        "identifier" => "PRJ-104",
        "title" => "No assignee",
        "description" => nil,
        "priority" => nil,
        "state" => %{"name" => "Todo"},
        "branchName" => nil,
        "url" => nil,
        "assignee" => nil,
        "labels" => %{"nodes" => []},
        "inverseRelations" => %{"nodes" => []},
        "createdAt" => nil,
        "updatedAt" => nil
      }

      issue = Client.normalize_issue_for_test(raw, "user-xyz")
      assert issue.assigned_to_worker == false
    end

    test "assigned_to_worker is true when no assignee filter (nil)" do
      raw = %{
        "id" => "issue-6",
        "identifier" => "PRJ-105",
        "title" => "No filter",
        "description" => nil,
        "priority" => nil,
        "state" => %{"name" => "Todo"},
        "branchName" => nil,
        "url" => nil,
        "assignee" => %{"id" => "anyone"},
        "labels" => %{"nodes" => []},
        "inverseRelations" => %{"nodes" => []},
        "createdAt" => nil,
        "updatedAt" => nil
      }

      issue = Client.normalize_issue_for_test(raw, nil)
      assert issue.assigned_to_worker == true
    end
  end

  describe "label extraction" do
    test "extracts and downcases labels" do
      raw = %{
        "id" => "issue-labels",
        "identifier" => "PRJ-200",
        "title" => "Labels test",
        "description" => nil,
        "priority" => nil,
        "state" => %{"name" => "Todo"},
        "branchName" => nil,
        "url" => nil,
        "assignee" => nil,
        "labels" => %{"nodes" => [%{"name" => "Frontend"}, %{"name" => "URGENT"}, %{"name" => "bug"}]},
        "inverseRelations" => %{"nodes" => []},
        "createdAt" => nil,
        "updatedAt" => nil
      }

      issue = Client.normalize_issue_for_test(raw)
      assert issue.labels == ["frontend", "urgent", "bug"]
    end

    test "handles missing labels gracefully" do
      raw = %{
        "id" => "issue-no-labels",
        "identifier" => "PRJ-201",
        "title" => "No labels",
        "description" => nil,
        "priority" => nil,
        "state" => %{"name" => "Todo"},
        "branchName" => nil,
        "url" => nil,
        "assignee" => nil,
        "createdAt" => nil,
        "updatedAt" => nil
      }

      issue = Client.normalize_issue_for_test(raw)
      assert issue.labels == []
    end

    test "filters out nil label names" do
      raw = %{
        "id" => "issue-nil-labels",
        "identifier" => "PRJ-202",
        "title" => "Nil label names",
        "description" => nil,
        "priority" => nil,
        "state" => %{"name" => "Todo"},
        "branchName" => nil,
        "url" => nil,
        "assignee" => nil,
        "labels" => %{"nodes" => [%{"name" => "valid"}, %{"name" => nil}]},
        "inverseRelations" => %{"nodes" => []},
        "createdAt" => nil,
        "updatedAt" => nil
      }

      issue = Client.normalize_issue_for_test(raw)
      assert issue.labels == ["valid"]
    end
  end

  describe "blocker extraction" do
    test "extracts blockers from inverse relations with type blocks" do
      raw = %{
        "id" => "issue-blocked",
        "identifier" => "PRJ-300",
        "title" => "Blocked issue",
        "description" => nil,
        "priority" => nil,
        "state" => %{"name" => "Todo"},
        "branchName" => nil,
        "url" => nil,
        "assignee" => nil,
        "labels" => %{"nodes" => []},
        "inverseRelations" => %{
          "nodes" => [
            %{
              "type" => "blocks",
              "issue" => %{
                "id" => "blocker-1",
                "identifier" => "PRJ-299",
                "state" => %{"name" => "In Progress"}
              }
            },
            %{
              "type" => "relates",
              "issue" => %{
                "id" => "related-1",
                "identifier" => "PRJ-298",
                "state" => %{"name" => "Done"}
              }
            }
          ]
        },
        "createdAt" => nil,
        "updatedAt" => nil
      }

      issue = Client.normalize_issue_for_test(raw)

      assert length(issue.blocked_by) == 1
      blocker = hd(issue.blocked_by)
      assert blocker.id == "blocker-1"
      assert blocker.identifier == "PRJ-299"
      assert blocker.state == "In Progress"
    end

    test "handles case-insensitive blocks type" do
      raw = %{
        "id" => "issue-blocked-2",
        "identifier" => "PRJ-301",
        "title" => "Case insensitive blocks",
        "description" => nil,
        "priority" => nil,
        "state" => %{"name" => "Todo"},
        "branchName" => nil,
        "url" => nil,
        "assignee" => nil,
        "labels" => %{"nodes" => []},
        "inverseRelations" => %{
          "nodes" => [
            %{
              "type" => "  Blocks  ",
              "issue" => %{
                "id" => "blocker-2",
                "identifier" => "PRJ-300",
                "state" => %{"name" => "Todo"}
              }
            }
          ]
        },
        "createdAt" => nil,
        "updatedAt" => nil
      }

      issue = Client.normalize_issue_for_test(raw)
      assert length(issue.blocked_by) == 1
    end

    test "returns empty list when no inverse relations" do
      raw = %{
        "id" => "issue-no-blockers",
        "identifier" => "PRJ-302",
        "title" => "No blockers",
        "description" => nil,
        "priority" => nil,
        "state" => %{"name" => "Todo"},
        "branchName" => nil,
        "url" => nil,
        "assignee" => nil,
        "labels" => %{"nodes" => []},
        "createdAt" => nil,
        "updatedAt" => nil
      }

      issue = Client.normalize_issue_for_test(raw)
      assert issue.blocked_by == []
    end
  end

  describe "datetime parsing" do
    test "parses valid ISO8601 datetimes" do
      raw = %{
        "id" => "issue-dt",
        "identifier" => "PRJ-400",
        "title" => "Datetime test",
        "description" => nil,
        "priority" => nil,
        "state" => %{"name" => "Todo"},
        "branchName" => nil,
        "url" => nil,
        "assignee" => nil,
        "labels" => %{"nodes" => []},
        "inverseRelations" => %{"nodes" => []},
        "createdAt" => "2025-01-15T10:30:00.000Z",
        "updatedAt" => "2025-01-16T08:00:00.000Z"
      }

      issue = Client.normalize_issue_for_test(raw)

      assert issue.created_at.year == 2025
      assert issue.created_at.month == 1
      assert issue.created_at.day == 15
      assert issue.updated_at.day == 16
    end

    test "returns nil for invalid datetime strings" do
      raw = %{
        "id" => "issue-bad-dt",
        "identifier" => "PRJ-401",
        "title" => "Bad datetime",
        "description" => nil,
        "priority" => nil,
        "state" => %{"name" => "Todo"},
        "branchName" => nil,
        "url" => nil,
        "assignee" => nil,
        "labels" => %{"nodes" => []},
        "inverseRelations" => %{"nodes" => []},
        "createdAt" => "not-a-date",
        "updatedAt" => nil
      }

      issue = Client.normalize_issue_for_test(raw)
      assert issue.created_at == nil
      assert issue.updated_at == nil
    end
  end

  describe "priority parsing" do
    test "passes through integer priority" do
      raw = %{
        "id" => "issue-pri",
        "identifier" => "PRJ-500",
        "title" => "Priority test",
        "description" => nil,
        "priority" => 3,
        "state" => %{"name" => "Todo"},
        "branchName" => nil,
        "url" => nil,
        "assignee" => nil,
        "labels" => %{"nodes" => []},
        "inverseRelations" => %{"nodes" => []},
        "createdAt" => nil,
        "updatedAt" => nil
      }

      issue = Client.normalize_issue_for_test(raw)
      assert issue.priority == 3
    end

    test "returns nil for non-integer priority" do
      raw = %{
        "id" => "issue-pri-nil",
        "identifier" => "PRJ-501",
        "title" => "Nil priority",
        "description" => nil,
        "priority" => "high",
        "state" => %{"name" => "Todo"},
        "branchName" => nil,
        "url" => nil,
        "assignee" => nil,
        "labels" => %{"nodes" => []},
        "inverseRelations" => %{"nodes" => []},
        "createdAt" => nil,
        "updatedAt" => nil
      }

      issue = Client.normalize_issue_for_test(raw)
      assert issue.priority == nil
    end
  end

  describe "next_page_cursor_for_test/1" do
    test "returns {:ok, cursor} when has_next_page is true with valid cursor" do
      assert {:ok, "cursor-abc"} = Client.next_page_cursor_for_test(%{has_next_page: true, end_cursor: "cursor-abc"})
    end

    test "returns :done when has_next_page is false" do
      assert :done = Client.next_page_cursor_for_test(%{has_next_page: false, end_cursor: "cursor-abc"})
    end

    test "returns :done when has_next_page is nil" do
      assert :done = Client.next_page_cursor_for_test(%{has_next_page: nil})
    end

    test "returns error when has_next_page is true but end_cursor is missing" do
      assert {:error, :linear_missing_end_cursor} = Client.next_page_cursor_for_test(%{has_next_page: true})
    end

    test "returns error when has_next_page is true but end_cursor is empty" do
      assert {:error, :linear_missing_end_cursor} = Client.next_page_cursor_for_test(%{has_next_page: true, end_cursor: ""})
    end
  end

  describe "merge_issue_pages_for_test/1" do
    test "merges multiple pages preserving order" do
      page1 = [
        %Issue{id: "a", identifier: "P-1"},
        %Issue{id: "b", identifier: "P-2"}
      ]

      page2 = [
        %Issue{id: "c", identifier: "P-3"}
      ]

      page3 = [
        %Issue{id: "d", identifier: "P-4"},
        %Issue{id: "e", identifier: "P-5"}
      ]

      result = Client.merge_issue_pages_for_test([page1, page2, page3])

      assert length(result) == 5
      assert Enum.map(result, & &1.id) == ["a", "b", "c", "d", "e"]
    end

    test "handles empty pages" do
      result = Client.merge_issue_pages_for_test([[], [], []])
      assert result == []
    end

    test "handles single page" do
      page = [%Issue{id: "x", identifier: "P-10"}]
      result = Client.merge_issue_pages_for_test([page])
      assert length(result) == 1
      assert hd(result).id == "x"
    end
  end

  describe "graphql/3" do
    test "returns parsed body on 200 response" do
      request_fun = fn _payload, _headers ->
        {:ok, %{status: 200, body: %{"data" => %{"viewer" => %{"id" => "user-1"}}}}}
      end

      write_workflow_file!(Workflow.workflow_file_path(), tracker_api_token: "test-token")

      assert {:ok, %{"data" => %{"viewer" => %{"id" => "user-1"}}}} =
               Client.graphql("query { viewer { id } }", %{}, request_fun: request_fun)
    end

    test "returns error on non-200 status" do
      request_fun = fn _payload, _headers ->
        {:ok, %{status: 401, body: "Unauthorized"}}
      end

      write_workflow_file!(Workflow.workflow_file_path(), tracker_api_token: "bad-token")

      log =
        capture_log(fn ->
          assert {:error, {:linear_api_status, 401}} =
                   Client.graphql("query { viewer { id } }", %{}, request_fun: request_fun)
        end)

      assert log =~ "Linear GraphQL request failed status=401"
    end

    test "returns error on request failure" do
      request_fun = fn _payload, _headers ->
        {:error, :timeout}
      end

      write_workflow_file!(Workflow.workflow_file_path(), tracker_api_token: "test-token")

      log =
        capture_log(fn ->
          assert {:error, {:linear_api_request, :timeout}} =
                   Client.graphql("query { viewer { id } }", %{}, request_fun: request_fun)
        end)

      assert log =~ "Linear GraphQL request failed"
    end

    test "returns error when API token is missing" do
      write_workflow_file!(Workflow.workflow_file_path(), tracker_api_token: nil)

      assert {:error, :missing_linear_api_token} =
               Client.graphql("query { viewer { id } }", %{})
    end
  end

  describe "fetch_candidate_issues/0" do
    test "returns error when API token is missing" do
      write_workflow_file!(Workflow.workflow_file_path(), tracker_api_token: nil)
      assert {:error, :missing_linear_api_token} = Client.fetch_candidate_issues()
    end

    test "returns error when project slug is missing" do
      write_workflow_file!(Workflow.workflow_file_path(), tracker_api_token: "token", tracker_project_slug: nil)
      assert {:error, :missing_linear_project_slug} = Client.fetch_candidate_issues()
    end
  end

  describe "fetch_issues_by_states/1" do
    test "returns {:ok, []} for empty state list" do
      assert {:ok, []} = Client.fetch_issues_by_states([])
    end

    test "returns error when API token is missing" do
      write_workflow_file!(Workflow.workflow_file_path(), tracker_api_token: nil)
      assert {:error, :missing_linear_api_token} = Client.fetch_issues_by_states(["Todo"])
    end

    test "returns error when project slug is missing" do
      write_workflow_file!(Workflow.workflow_file_path(), tracker_api_token: "token", tracker_project_slug: nil)
      assert {:error, :missing_linear_project_slug} = Client.fetch_issues_by_states(["Todo"])
    end
  end

  describe "fetch_issue_states_by_ids/1" do
    test "returns {:ok, []} for empty ID list" do
      assert {:ok, []} = Client.fetch_issue_states_by_ids([])
    end
  end
end

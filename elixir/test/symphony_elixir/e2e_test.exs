defmodule SymphonyElixir.E2ETest do
  use SymphonyElixir.TestSupport

  alias SymphonyElixir.Tracker.Memory

  describe "Linear Client issue normalization pipeline" do
    test "normalizes a full API response with pagination through test helpers" do
      page1_issues = [
        %{
          "id" => "e2e-1",
          "identifier" => "E2E-1",
          "title" => "First issue",
          "description" => "First issue description",
          "priority" => 1,
          "state" => %{"name" => "Todo"},
          "branchName" => "e2e-1-first",
          "url" => "https://linear.app/e2e/E2E-1",
          "assignee" => %{"id" => "user-e2e"},
          "labels" => %{"nodes" => [%{"name" => "Feature"}]},
          "inverseRelations" => %{"nodes" => []},
          "createdAt" => "2025-03-01T10:00:00.000Z",
          "updatedAt" => "2025-03-02T12:00:00.000Z"
        },
        %{
          "id" => "e2e-2",
          "identifier" => "E2E-2",
          "title" => "Second issue",
          "description" => nil,
          "priority" => 3,
          "state" => %{"name" => "In Progress"},
          "branchName" => nil,
          "url" => "https://linear.app/e2e/E2E-2",
          "assignee" => nil,
          "labels" => %{"nodes" => []},
          "inverseRelations" => %{
            "nodes" => [
              %{
                "type" => "blocks",
                "issue" => %{
                  "id" => "blocker-e2e",
                  "identifier" => "E2E-0",
                  "state" => %{"name" => "In Progress"}
                }
              }
            ]
          },
          "createdAt" => "2025-03-03T08:00:00.000Z",
          "updatedAt" => nil
        }
      ]

      page2_issues = [
        %{
          "id" => "e2e-3",
          "identifier" => "E2E-3",
          "title" => "Third issue",
          "description" => "Page 2 issue",
          "priority" => nil,
          "state" => %{"name" => "Todo"},
          "branchName" => "e2e-3-third",
          "url" => "https://linear.app/e2e/E2E-3",
          "assignee" => %{"id" => "user-e2e"},
          "labels" => %{"nodes" => [%{"name" => "Bug"}, %{"name" => "Critical"}]},
          "inverseRelations" => %{"nodes" => []},
          "createdAt" => "2025-03-05T14:00:00.000Z",
          "updatedAt" => "2025-03-06T09:00:00.000Z"
        }
      ]

      # Normalize all issues as if they came from the API
      normalized_page1 = Enum.map(page1_issues, &Client.normalize_issue_for_test/1)
      normalized_page2 = Enum.map(page2_issues, &Client.normalize_issue_for_test/1)

      # Merge pages preserving order
      all_issues = Client.merge_issue_pages_for_test([normalized_page1, normalized_page2])

      assert length(all_issues) == 3
      assert Enum.map(all_issues, & &1.identifier) == ["E2E-1", "E2E-2", "E2E-3"]

      # Verify first issue normalization
      first = Enum.at(all_issues, 0)
      assert first.priority == 1
      assert first.labels == ["feature"]
      assert first.assignee_id == "user-e2e"
      assert %DateTime{} = first.created_at

      # Verify second issue with blocker
      second = Enum.at(all_issues, 1)
      assert length(second.blocked_by) == 1
      assert hd(second.blocked_by).identifier == "E2E-0"
      assert second.assignee_id == nil

      # Verify third issue labels
      third = Enum.at(all_issues, 2)
      assert third.labels == ["bug", "critical"]
    end

    test "pagination cursor signals correctly across pages" do
      # Page 1: has more pages
      page1_info = %{has_next_page: true, end_cursor: "cursor-page2"}
      assert {:ok, "cursor-page2"} = Client.next_page_cursor_for_test(page1_info)

      # Page 2: has more pages
      page2_info = %{has_next_page: true, end_cursor: "cursor-page3"}
      assert {:ok, "cursor-page3"} = Client.next_page_cursor_for_test(page2_info)

      # Page 3: last page
      page3_info = %{has_next_page: false, end_cursor: nil}
      assert :done = Client.next_page_cursor_for_test(page3_info)
    end
  end

  describe "PromptBuilder and Workflow integration" do
    test "loads workflow file, builds prompt with issue data, and renders correctly" do
      template = """
      You are working on issue {{ issue.identifier }}: {{ issue.title }}

      Description: {{ issue.description }}
      State: {{ issue.state }}
      URL: {{ issue.url }}

      {% if issue.labels.size > 0 %}Labels: {% for label in issue.labels %}{{ label }}{% unless forloop.last %}, {% endunless %}{% endfor %}{% endif %}
      """

      write_workflow_file!(Workflow.workflow_file_path(), prompt: template)

      issue = %Issue{
        id: "e2e-prompt-1",
        identifier: "PRJ-E2E-1",
        title: "Implement dark mode",
        description: "Add dark mode toggle to settings page",
        state: "In Progress",
        url: "https://linear.app/prj/PRJ-E2E-1",
        labels: ["frontend", "enhancement"]
      }

      prompt = PromptBuilder.build_prompt(issue)

      assert prompt =~ "PRJ-E2E-1"
      assert prompt =~ "Implement dark mode"
      assert prompt =~ "Add dark mode toggle to settings page"
      assert prompt =~ "In Progress"
      assert prompt =~ "frontend"
      assert prompt =~ "enhancement"
    end

    test "prompt builder handles workflow reload after file change" do
      write_workflow_file!(Workflow.workflow_file_path(), prompt: "Version 1: {{ issue.title }}")

      issue = %Issue{id: "e2e-prompt-2", identifier: "PRJ-E2E-2", title: "Test reload"}

      prompt1 = PromptBuilder.build_prompt(issue)
      assert prompt1 =~ "Version 1: Test reload"

      # Update the workflow file
      write_workflow_file!(Workflow.workflow_file_path(), prompt: "Version 2: {{ issue.title }}")

      prompt2 = PromptBuilder.build_prompt(issue)
      assert prompt2 =~ "Version 2: Test reload"
    end
  end

  describe "Memory Tracker through Tracker adapter boundary" do
    test "routes through Tracker module when tracker_kind is memory" do
      write_workflow_file!(Workflow.workflow_file_path(), tracker_kind: "memory")

      issues = [
        %Issue{id: "e2e-t1", identifier: "E2E-T1", title: "Memory issue 1", state: "Todo"},
        %Issue{id: "e2e-t2", identifier: "E2E-T2", title: "Memory issue 2", state: "In Progress"},
        %Issue{id: "e2e-t3", identifier: "E2E-T3", title: "Memory issue 3", state: "Done"}
      ]

      Application.put_env(:symphony_elixir, :memory_tracker_issues, issues)
      Application.put_env(:symphony_elixir, :memory_tracker_recipient, self())

      # Fetch all candidates
      assert {:ok, all} = Tracker.fetch_candidate_issues()
      assert length(all) == 3

      # Filter by state
      assert {:ok, active} = Tracker.fetch_issues_by_states(["Todo", "In Progress"])
      assert length(active) == 2

      # Fetch by IDs
      assert {:ok, by_id} = Tracker.fetch_issue_states_by_ids(["e2e-t1", "e2e-t3"])
      assert length(by_id) == 2

      # Create comment
      assert :ok = Tracker.create_comment("e2e-t1", "E2E comment")
      assert_received {:memory_tracker_comment, "e2e-t1", "E2E comment"}

      # Update state
      assert :ok = Tracker.update_issue_state("e2e-t2", "Done")
      assert_received {:memory_tracker_state_update, "e2e-t2", "Done"}
    end
  end

  describe "Workspace lifecycle" do
    test "creates workspace, runs hooks, and removes workspace" do
      test_root =
        Path.join(
          System.tmp_dir!(),
          "symphony-elixir-e2e-workspace-#{System.unique_integer([:positive])}"
        )

      try do
        workspace_root = Path.join(test_root, "workspaces")
        File.mkdir_p!(workspace_root)

        hook_trace = Path.join(test_root, "hook-trace.log")

        write_workflow_file!(Workflow.workflow_file_path(),
          workspace_root: workspace_root,
          hook_before_run: "echo before_run >> #{hook_trace}",
          hook_after_run: "echo after_run >> #{hook_trace}"
        )

        issue = %Issue{
          id: "e2e-ws-1",
          identifier: "E2E-WS-1",
          title: "Workspace lifecycle",
          state: "In Progress"
        }

        # Create workspace
        assert {:ok, workspace} = Workspace.create_for_issue(issue)
        assert File.dir?(workspace)

        # Run before_run hook
        assert :ok = Workspace.run_before_run_hook(workspace, issue)

        # Run after_run hook
        assert :ok = Workspace.run_after_run_hook(workspace, issue)

        # Verify hooks ran
        assert File.exists?(hook_trace)
        trace_content = File.read!(hook_trace)
        assert trace_content =~ "before_run"
        assert trace_content =~ "after_run"

        # Remove workspace
        assert {:ok, _} = Workspace.remove(workspace)
        refute File.dir?(workspace)
      after
        File.rm_rf(test_root)
      end
    end

    test "workspace creation is idempotent for existing directories" do
      test_root =
        Path.join(
          System.tmp_dir!(),
          "symphony-elixir-e2e-ws-idempotent-#{System.unique_integer([:positive])}"
        )

      try do
        workspace_root = Path.join(test_root, "workspaces")
        File.mkdir_p!(workspace_root)

        write_workflow_file!(Workflow.workflow_file_path(), workspace_root: workspace_root)

        issue = %Issue{id: "e2e-ws-2", identifier: "E2E-WS-2", title: "Idempotent", state: "Todo"}

        # Create workspace twice
        assert {:ok, workspace1} = Workspace.create_for_issue(issue)
        assert {:ok, workspace2} = Workspace.create_for_issue(issue)

        assert workspace1 == workspace2
        assert File.dir?(workspace1)
      after
        File.rm_rf(test_root)
      end
    end

    test "workspace safe_identifier sanitizes special characters" do
      test_root =
        Path.join(
          System.tmp_dir!(),
          "symphony-elixir-e2e-ws-sanitize-#{System.unique_integer([:positive])}"
        )

      try do
        workspace_root = Path.join(test_root, "workspaces")
        File.mkdir_p!(workspace_root)

        write_workflow_file!(Workflow.workflow_file_path(), workspace_root: workspace_root)

        issue = %Issue{id: "e2e-ws-3", identifier: "PRJ/WS#3@special!", title: "Sanitize test", state: "Todo"}

        assert {:ok, workspace} = Workspace.create_for_issue(issue)
        # The workspace directory name should only contain safe characters
        dirname = Path.basename(workspace)
        assert dirname =~ ~r/^[a-zA-Z0-9._-]+$/
        assert File.dir?(workspace)
      after
        File.rm_rf(test_root)
      end
    end
  end

  describe "Linear Client graphql with multi-page simulated response" do
    test "fetches and merges multi-page responses via request_fun" do
      write_workflow_file!(Workflow.workflow_file_path(),
        tracker_api_token: "test-token",
        tracker_project_slug: "test-project",
        tracker_assignee: nil
      )

      call_count = :counters.new(1, [:atomics])

      request_fun = fn _payload, _headers ->
        :counters.add(call_count, 1, 1)
        current = :counters.get(call_count, 1)

        case current do
          1 ->
            {:ok,
             %{
               status: 200,
               body: %{
                 "data" => %{
                   "issues" => %{
                     "nodes" => [
                       %{
                         "id" => "mp-1",
                         "identifier" => "MP-1",
                         "title" => "Page 1 Issue",
                         "description" => nil,
                         "priority" => 1,
                         "state" => %{"name" => "Todo"},
                         "branchName" => nil,
                         "url" => nil,
                         "assignee" => nil,
                         "labels" => %{"nodes" => []},
                         "inverseRelations" => %{"nodes" => []},
                         "createdAt" => nil,
                         "updatedAt" => nil
                       }
                     ],
                     "pageInfo" => %{"hasNextPage" => true, "endCursor" => "cursor-2"}
                   }
                 }
               }
             }}

          2 ->
            {:ok,
             %{
               status: 200,
               body: %{
                 "data" => %{
                   "issues" => %{
                     "nodes" => [
                       %{
                         "id" => "mp-2",
                         "identifier" => "MP-2",
                         "title" => "Page 2 Issue",
                         "description" => nil,
                         "priority" => 2,
                         "state" => %{"name" => "In Progress"},
                         "branchName" => nil,
                         "url" => nil,
                         "assignee" => nil,
                         "labels" => %{"nodes" => []},
                         "inverseRelations" => %{"nodes" => []},
                         "createdAt" => nil,
                         "updatedAt" => nil
                       }
                     ],
                     "pageInfo" => %{"hasNextPage" => false, "endCursor" => nil}
                   }
                 }
               }
             }}

          _ ->
            {:error, :unexpected_call}
        end
      end

      # Use graphql directly to simulate paginated fetch
      assert {:ok, body1} =
               Client.graphql(
                 "query { issues { nodes { id } pageInfo { hasNextPage endCursor } } }",
                 %{},
                 request_fun: request_fun
               )

      page1_nodes = get_in(body1, ["data", "issues", "nodes"])
      page1_info = get_in(body1, ["data", "issues", "pageInfo"])

      assert length(page1_nodes) == 1
      assert page1_info["hasNextPage"] == true

      assert {:ok, body2} =
               Client.graphql(
                 "query { issues { nodes { id } pageInfo { hasNextPage endCursor } } }",
                 %{after: page1_info["endCursor"]},
                 request_fun: request_fun
               )

      page2_nodes = get_in(body2, ["data", "issues", "nodes"])
      page2_info = get_in(body2, ["data", "issues", "pageInfo"])

      assert length(page2_nodes) == 1
      assert page2_info["hasNextPage"] == false

      # Normalize and merge all pages
      all_normalized =
        Client.merge_issue_pages_for_test([
          Enum.map(page1_nodes, &Client.normalize_issue_for_test/1),
          Enum.map(page2_nodes, &Client.normalize_issue_for_test/1)
        ])

      assert length(all_normalized) == 2
      assert Enum.map(all_normalized, & &1.identifier) == ["MP-1", "MP-2"]
    end
  end
end

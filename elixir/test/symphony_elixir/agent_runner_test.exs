defmodule SymphonyElixir.AgentRunnerTest do
  use SymphonyElixir.TestSupport

  describe "run/3" do
    test "raises when workspace creation fails" do
      write_workflow_file!(Workflow.workflow_file_path(),
        workspace_root: "/nonexistent/root/that/cannot/exist"
      )

      issue = %Issue{
        id: "issue-ar-1",
        identifier: "MT-AR-1",
        title: "Workspace fail test",
        description: "Test that run raises on workspace failure",
        state: "In Progress"
      }

      assert_raise RuntimeError, ~r/Agent run failed/, fn ->
        AgentRunner.run(issue)
      end
    end

    test "completes single turn when issue moves to non-active state" do
      test_root =
        Path.join(
          System.tmp_dir!(),
          "symphony-elixir-agent-runner-single-#{System.unique_integer([:positive])}"
        )

      try do
        workspace_root = Path.join(test_root, "workspaces")
        workspace = Path.join(workspace_root, "MT-AR-2")
        codex_binary = Path.join(test_root, "fake-codex")
        File.mkdir_p!(workspace)

        File.write!(codex_binary, """
        #!/bin/sh
        count=0
        while IFS= read -r line; do
          count=$((count + 1))

          case "$count" in
            1)
              printf '%s\\n' '{"id":1,"result":{}}'
              ;;
            2)
              ;;
            3)
              printf '%s\\n' '{"id":2,"result":{"thread":{"id":"thread-ar2"}}}'
              ;;
            4)
              printf '%s\\n' '{"id":3,"result":{"turn":{"id":"turn-ar2"}}}'
              printf '%s\\n' '{"method":"turn/completed"}'
              exit 0
              ;;
            *)
              exit 0
              ;;
          esac
        done
        """)

        File.chmod!(codex_binary, 0o755)

        write_workflow_file!(Workflow.workflow_file_path(),
          workspace_root: workspace_root,
          codex_command: "#{codex_binary} app-server"
        )

        issue = %Issue{
          id: "issue-ar-2",
          identifier: "MT-AR-2",
          title: "Single turn test",
          description: "Agent should complete after one turn",
          state: "In Progress",
          url: "https://example.com/MT-AR-2",
          labels: []
        }

        # Issue state fetcher returns issue in "Done" state (non-active)
        issue_state_fetcher = fn [_id] ->
          {:ok, [%Issue{issue | state: "Done"}]}
        end

        assert :ok = AgentRunner.run(issue, nil, max_turns: 3, issue_state_fetcher: issue_state_fetcher)
      after
        File.rm_rf(test_root)
      end
    end

    test "continues for multiple turns when issue stays in active state" do
      test_root =
        Path.join(
          System.tmp_dir!(),
          "symphony-elixir-agent-runner-multi-#{System.unique_integer([:positive])}"
        )

      try do
        workspace_root = Path.join(test_root, "workspaces")
        workspace = Path.join(workspace_root, "MT-AR-3")
        codex_binary = Path.join(test_root, "fake-codex")
        File.mkdir_p!(workspace)

        # This fake codex always completes turns successfully
        File.write!(codex_binary, """
        #!/bin/sh
        count=0
        while IFS= read -r line; do
          count=$((count + 1))

          case "$count" in
            1)
              printf '%s\\n' '{"id":1,"result":{}}'
              ;;
            2)
              ;;
            3)
              printf '%s\\n' '{"id":2,"result":{"thread":{"id":"thread-ar3"}}}'
              ;;
            4)
              printf '%s\\n' '{"id":3,"result":{"turn":{"id":"turn-ar3"}}}'
              printf '%s\\n' '{"method":"turn/completed"}'
              ;;
            5)
              printf '%s\\n' '{"id":3,"result":{"turn":{"id":"turn-ar3b"}}}'
              printf '%s\\n' '{"method":"turn/completed"}'
              exit 0
              ;;
            *)
              exit 0
              ;;
          esac
        done
        """)

        File.chmod!(codex_binary, 0o755)

        write_workflow_file!(Workflow.workflow_file_path(),
          workspace_root: workspace_root,
          codex_command: "#{codex_binary} app-server"
        )

        issue = %Issue{
          id: "issue-ar-3",
          identifier: "MT-AR-3",
          title: "Multi turn test",
          description: "Agent should continue for 2 turns then stop at max",
          state: "In Progress",
          url: "https://example.com/MT-AR-3",
          labels: []
        }

        turn_count = :counters.new(1, [:atomics])

        issue_state_fetcher = fn [_id] ->
          :counters.add(turn_count, 1, 1)
          # Always return issue still in active state
          {:ok, [%Issue{issue | state: "In Progress"}]}
        end

        assert :ok = AgentRunner.run(issue, nil, max_turns: 2, issue_state_fetcher: issue_state_fetcher)

        # Should have checked issue state at least once (continuation check)
        assert :counters.get(turn_count, 1) >= 1
      after
        File.rm_rf(test_root)
      end
    end

    test "sends codex updates to recipient pid" do
      test_root =
        Path.join(
          System.tmp_dir!(),
          "symphony-elixir-agent-runner-updates-#{System.unique_integer([:positive])}"
        )

      try do
        workspace_root = Path.join(test_root, "workspaces")
        workspace = Path.join(workspace_root, "MT-AR-4")
        codex_binary = Path.join(test_root, "fake-codex")
        File.mkdir_p!(workspace)

        File.write!(codex_binary, """
        #!/bin/sh
        count=0
        while IFS= read -r line; do
          count=$((count + 1))

          case "$count" in
            1)
              printf '%s\\n' '{"id":1,"result":{}}'
              ;;
            2)
              ;;
            3)
              printf '%s\\n' '{"id":2,"result":{"thread":{"id":"thread-ar4"}}}'
              ;;
            4)
              printf '%s\\n' '{"id":3,"result":{"turn":{"id":"turn-ar4"}}}'
              printf '%s\\n' '{"method":"turn/completed"}'
              exit 0
              ;;
            *)
              exit 0
              ;;
          esac
        done
        """)

        File.chmod!(codex_binary, 0o755)

        write_workflow_file!(Workflow.workflow_file_path(),
          workspace_root: workspace_root,
          codex_command: "#{codex_binary} app-server"
        )

        issue = %Issue{
          id: "issue-ar-4",
          identifier: "MT-AR-4",
          title: "Update recipient test",
          description: "Test codex updates are sent to recipient",
          state: "In Progress",
          url: "https://example.com/MT-AR-4",
          labels: []
        }

        issue_state_fetcher = fn [_id] ->
          {:ok, [%Issue{issue | state: "Done"}]}
        end

        recipient = self()

        assert :ok = AgentRunner.run(issue, recipient, max_turns: 1, issue_state_fetcher: issue_state_fetcher)

        # Should receive at least one codex_worker_update message
        assert_received {:codex_worker_update, "issue-ar-4", _message}
      after
        File.rm_rf(test_root)
      end
    end

    test "returns :ok when issue disappears during state refresh (empty list)" do
      test_root =
        Path.join(
          System.tmp_dir!(),
          "symphony-elixir-agent-runner-vanish-#{System.unique_integer([:positive])}"
        )

      try do
        workspace_root = Path.join(test_root, "workspaces")
        workspace = Path.join(workspace_root, "MT-AR-5")
        codex_binary = Path.join(test_root, "fake-codex")
        File.mkdir_p!(workspace)

        File.write!(codex_binary, """
        #!/bin/sh
        count=0
        while IFS= read -r line; do
          count=$((count + 1))

          case "$count" in
            1)
              printf '%s\\n' '{"id":1,"result":{}}'
              ;;
            2)
              ;;
            3)
              printf '%s\\n' '{"id":2,"result":{"thread":{"id":"thread-ar5"}}}'
              ;;
            4)
              printf '%s\\n' '{"id":3,"result":{"turn":{"id":"turn-ar5"}}}'
              printf '%s\\n' '{"method":"turn/completed"}'
              exit 0
              ;;
            *)
              exit 0
              ;;
          esac
        done
        """)

        File.chmod!(codex_binary, 0o755)

        write_workflow_file!(Workflow.workflow_file_path(),
          workspace_root: workspace_root,
          codex_command: "#{codex_binary} app-server"
        )

        issue = %Issue{
          id: "issue-ar-5",
          identifier: "MT-AR-5",
          title: "Vanishing issue test",
          description: "Issue disappears during state refresh",
          state: "In Progress",
          url: "https://example.com/MT-AR-5",
          labels: []
        }

        # Issue state fetcher returns empty list (issue vanished)
        issue_state_fetcher = fn [_id] ->
          {:ok, []}
        end

        assert :ok = AgentRunner.run(issue, nil, max_turns: 3, issue_state_fetcher: issue_state_fetcher)
      after
        File.rm_rf(test_root)
      end
    end
  end
end

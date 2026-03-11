defmodule SymphonyElixir.WorkflowStoreTest do
  use ExUnit.Case, async: false

  alias SymphonyElixir.Workflow
  alias SymphonyElixir.WorkflowStore

  import SymphonyElixir.TestSupport, only: [write_workflow_file!: 2]

  defp stop_workflow_store! do
    # Terminate via the app supervisor (prevents automatic restart)
    Supervisor.terminate_child(SymphonyElixir.Supervisor, WorkflowStore)

    # Also stop any ExUnit-supervised instance (stop_supervised prevents restart)
    stop_supervised(WorkflowStore)

    # Final safety: if still registered via another mechanism, force stop
    if pid = Process.whereis(WorkflowStore) do
      Process.exit(pid, :kill)
      Process.sleep(10)
    end
  end

  setup do
    workflow_root =
      Path.join(
        System.tmp_dir!(),
        "symphony-elixir-workflow-store-test-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(workflow_root)
    workflow_file = Path.join(workflow_root, "WORKFLOW.md")

    # We must write an initial file to allow WorkflowStore to initialize successfully.
    write_workflow_file!(workflow_file, prompt: "Initial Prompt")

    # Set the path before starting or interacting with the application-started store
    Workflow.set_workflow_file_path(workflow_file)

    if Process.whereis(WorkflowStore) do
      WorkflowStore.force_reload()
    else
      # Start it if it's not already started
      start_supervised!({WorkflowStore, []})
    end

    on_exit(fn ->
      Application.delete_env(:symphony_elixir, :workflow_file_path)
      File.rm_rf(workflow_root)
    end)

    %{workflow_file: workflow_file}
  end

  test "current/0 returns the loaded workflow" do
    {:ok, workflow} = WorkflowStore.current()
    assert workflow.prompt == "Initial Prompt"
  end

  test "force_reload/0 picks up changes to the workflow file", %{workflow_file: workflow_file} do
    # Verify initial state
    {:ok, workflow} = WorkflowStore.current()
    assert workflow.prompt == "Initial Prompt"

    # Modify the file, this time avoiding `write_workflow_file!` because it automatically calls `force_reload/0`
    File.write!(workflow_file, """
    ---
    tracker:
      kind: "linear"
    ---
    Updated Prompt
    """)

    # Force a reload
    assert :ok = WorkflowStore.force_reload()

    # Now current/0 should return the new state
    {:ok, new_workflow} = WorkflowStore.current()
    assert new_workflow.prompt == "Updated Prompt"
  end

  test "keeps last known good configuration if workflow file becomes invalid", %{workflow_file: workflow_file} do
    # Verify initial state
    {:ok, workflow} = WorkflowStore.current()
    assert workflow.prompt == "Initial Prompt"

    # Write invalid content
    File.write!(workflow_file, "---\ninvalid yaml\n---")

    # Force reload
    assert {:error, :workflow_front_matter_not_a_map} = WorkflowStore.force_reload()

    # It should still serve the old valid workflow
    {:ok, workflow_after_error} = WorkflowStore.current()
    assert workflow_after_error.prompt == "Initial Prompt"
  end

  test "keeps last known good configuration if workflow file is deleted", %{workflow_file: workflow_file} do
    # Verify initial state
    {:ok, workflow} = WorkflowStore.current()
    assert workflow.prompt == "Initial Prompt"

    # Delete the file
    File.rm!(workflow_file)

    # Force reload
    assert {:error, :enoent} = WorkflowStore.force_reload()

    # It should still serve the old valid workflow
    {:ok, workflow_after_error} = WorkflowStore.current()
    assert workflow_after_error.prompt == "Initial Prompt"
  end

  test "polls for changes automatically", %{workflow_file: workflow_file} do
    # Verify initial state
    {:ok, workflow} = WorkflowStore.current()
    assert workflow.prompt == "Initial Prompt"

    # Modify the file
    File.write!(workflow_file, """
    ---
    tracker:
      kind: "linear"
    ---
    Polled Prompt
    """)

    # Manually trigger the :poll message that the GenServer schedules for itself
    send(Process.whereis(WorkflowStore), :poll)

    # Calling `current/0` also automatically reloads if the file has changed.
    {:ok, new_workflow} = WorkflowStore.current()
    assert new_workflow.prompt == "Polled Prompt"
  end

  test "current/0 falls back to Workflow.load when GenServer is not running", %{workflow_file: _workflow_file} do
    stop_workflow_store!()

    # Should still work via direct load fallback
    {:ok, workflow} = WorkflowStore.current()
    assert workflow.prompt == "Initial Prompt"
  end

  test "force_reload/0 falls back to Workflow.load when GenServer is not running", %{workflow_file: _workflow_file} do
    stop_workflow_store!()

    assert :ok = WorkflowStore.force_reload()
  end

  test "force_reload/0 fallback returns error when workflow file is missing", %{workflow_file: workflow_file} do
    stop_workflow_store!()
    File.rm!(workflow_file)

    assert {:error, {:missing_workflow_file, _, :enoent}} = WorkflowStore.force_reload()
  end

  test "start_link/1 fails when workflow file is missing" do
    stop_workflow_store!()
    Process.flag(:trap_exit, true)

    missing_path =
      Path.join(
        System.tmp_dir!(),
        "nonexistent-#{System.unique_integer([:positive])}/WORKFLOW.md"
      )

    Workflow.set_workflow_file_path(missing_path)

    assert {:error, {:missing_workflow_file, ^missing_path, :enoent}} = WorkflowStore.start_link([])
  end

  test "start_link/1 fails when workflow file has invalid YAML" do
    stop_workflow_store!()
    Process.flag(:trap_exit, true)

    invalid_root =
      Path.join(
        System.tmp_dir!(),
        "symphony-invalid-yaml-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(invalid_root)
    invalid_path = Path.join(invalid_root, "WORKFLOW.md")
    File.write!(invalid_path, "---\n- not-a-map\n---\nPrompt body\n")
    Workflow.set_workflow_file_path(invalid_path)

    assert {:error, :workflow_front_matter_not_a_map} = WorkflowStore.start_link([])

    File.rm_rf!(invalid_root)
  end

  test "handle_info(:poll) handles corrupted workflow file gracefully", %{workflow_file: workflow_file} do
    {:ok, workflow} = WorkflowStore.current()
    assert workflow.prompt == "Initial Prompt"

    # Corrupt the file
    File.write!(workflow_file, "---\n- not-a-map\n---\nBroken\n")

    # Simulate poll
    send(Process.whereis(WorkflowStore), :poll)
    # Give the GenServer time to process
    Process.sleep(50)

    # Should still serve the last known good workflow
    {:ok, workflow_after} = WorkflowStore.current()
    assert workflow_after.prompt == "Initial Prompt"
  end
end

defmodule SymphonyElixir.WorkflowStoreTest do
  use ExUnit.Case, async: false

  alias SymphonyElixir.Workflow
  alias SymphonyElixir.WorkflowStore

  import SymphonyElixir.TestSupport, only: [write_workflow_file!: 2]

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

  describe "initialization errors" do
    test "init/1 stops if workflow file is not found" do
      # Make sure the application's WorkflowStore is stopped cleanly
      if _pid = Process.whereis(SymphonyElixir.WorkflowStore) do
        Supervisor.terminate_child(SymphonyElixir.Supervisor, SymphonyElixir.WorkflowStore)
      end

      original_path = Workflow.workflow_file_path()

      # Attempt to start it pointing to a non-existent file
      Workflow.set_workflow_file_path("/path/to/nowhere/WORKFLOW.md")

      Process.flag(:trap_exit, true)

      assert {:error, {:missing_workflow_file, "/path/to/nowhere/WORKFLOW.md", :enoent}} =
               WorkflowStore.start_link()

      # Restore for other tests
      Workflow.set_workflow_file_path(original_path)
      Supervisor.restart_child(SymphonyElixir.Supervisor, SymphonyElixir.WorkflowStore)
    end
  end

  describe "fallback when unstarted" do
    setup do
      original_path = Workflow.workflow_file_path()

      if _pid = Process.whereis(SymphonyElixir.WorkflowStore) do
        Supervisor.terminate_child(SymphonyElixir.Supervisor, SymphonyElixir.WorkflowStore)
      end

      on_exit(fn ->
        Workflow.set_workflow_file_path(original_path)
        Supervisor.restart_child(SymphonyElixir.Supervisor, SymphonyElixir.WorkflowStore)
      end)

      :ok
    end

    test "current/0 loads workflow directly" do
      {:ok, workflow} = WorkflowStore.current()
      assert workflow.prompt == "Initial Prompt"
    end

    test "force_reload/0 returns :ok if file is valid" do
      assert :ok = WorkflowStore.force_reload()
    end

    test "force_reload/0 returns error if file is invalid" do
      Workflow.set_workflow_file_path("/path/to/nowhere/WORKFLOW.md")
      assert {:error, _} = WorkflowStore.force_reload()
    end
  end

  describe "polling errors" do
    test "ignores errors during poll and stays alive", %{workflow_file: workflow_file} do
      # Verify initial state
      {:ok, workflow} = WorkflowStore.current()
      assert workflow.prompt == "Initial Prompt"

      # Write invalid content
      File.write!(workflow_file, "---\ninvalid yaml\n---")

      # Send a poll message manually
      send(Process.whereis(WorkflowStore), :poll)

      # Yield to let GenServer process message
      :sys.get_state(SymphonyElixir.WorkflowStore)

      # GenServer should still be alive
      assert Process.whereis(WorkflowStore)

      # And should still return last good config
      {:ok, ^workflow} = WorkflowStore.current()
    end
  end
end

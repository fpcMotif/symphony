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

  describe "fallback when GenServer is not running" do
    setup do

      if pid = Process.whereis(WorkflowStore) do
        GenServer.stop(pid)
      end

      # Wait a tiny bit for process termination
      Process.sleep(10)
      :ok
    end

    test "current/0 falls back to Workflow.load/0" do
      # Provide a path to a real file so it loads properly instead of falling back to default cwd logic that happens to find the root one
      SymphonyElixir.Workflow.set_workflow_file_path(System.get_env("TEST_WORKFLOW_FILE") || "WORKFLOW.md")

      # Since we're trying to hit the _fallback_ logic of WorkflowStore.current(), and since we've stopped the app above,
      # it hits `Workflow.load()`.
      assert {:ok, _workflow} = WorkflowStore.current()
    end

    test "force_reload/0 falls back to Workflow.load/0 and returns ok", %{workflow_file: workflow_file} do
      # Provide valid file so it succeeds
      SymphonyElixir.Workflow.set_workflow_file_path(workflow_file)
      assert :ok = WorkflowStore.force_reload()
    end

    test "force_reload/0 returns error from Workflow.load/0 when file is bad", %{workflow_file: workflow_file} do
      # Make file invalid before calling
      File.write!(workflow_file, "---\ninvalid yaml\n---")
      assert {:error, :workflow_front_matter_not_a_map} = WorkflowStore.force_reload()
    end
  end

  describe "init/1 error path" do
    test "returns stop when workflow file cannot be loaded" do
      # Temporarily change the workflow file to something that does not exist
      SymphonyElixir.Workflow.set_workflow_file_path("/tmp/nonexistent_workflow_for_test.md")

      # start directly without name registration and linking to avoid crashing the test process/supervisor
      assert {:error, {:missing_workflow_file, _path, :enoent}} = GenServer.start(WorkflowStore, [])
    end
  end

  describe "start_link/1" do
    test "starts successfully and registers under the module name" do
      # GenServer is already running, so calling it again returns an error tuple
      assert {:error, {:already_started, _pid}} = WorkflowStore.start_link()
    end
  end

  describe "handle_info(:poll) error path" do
    test "keeps last known state when workflow file becomes invalid during poll", %{workflow_file: workflow_file} do
      # Verify initial state
      {:ok, workflow} = WorkflowStore.current()
      assert workflow.prompt == "Initial Prompt"

      # Write invalid content
      File.write!(workflow_file, "---\ninvalid yaml\n---")

      # Trigger a poll
      send(Process.whereis(WorkflowStore), :poll)

      # Give GenServer time to process the message
      Process.sleep(10)

      # Ensure it's still alive and has the old state
      assert Process.alive?(Process.whereis(WorkflowStore))
      {:ok, workflow_after_error} = WorkflowStore.current()
      assert workflow_after_error.prompt == "Initial Prompt"
    end
  end
end

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

  test "start_link/1 accepts options" do
    # We cannot test overriding the name because `WorkflowStore.start_link/1` hardcodes `name: __MODULE__` internally,
    # but we can verify it returns `{:error, {:already_started, pid}}` when the default one is running.
    assert {:error, {:already_started, _pid}} = WorkflowStore.start_link()
  end

  test "init/1 fails if the initial workflow file is missing" do
    # Create a non-existent path
    Workflow.set_workflow_file_path("/path/that/does/not/exist.md")

    # We test the init/1 function by temporarily killing the supervised one, or starting it without name
    pid = Process.whereis(WorkflowStore)
    Process.unregister(WorkflowStore)

    # This directly exercises init/1 which gets the path from Workflow.workflow_file_path()
    # Since start_link forces name: __MODULE__, and we unregistered it, it will try to start
    # and immediately fail and return the error
    Process.flag(:trap_exit, true)
    assert {:error, {:missing_workflow_file, _, :enoent}} = WorkflowStore.start_link()
    Process.flag(:trap_exit, false)

    Process.register(pid, WorkflowStore)
  end

  test "current/0 returns the loaded workflow" do
    {:ok, workflow} = WorkflowStore.current()
    assert workflow.prompt == "Initial Prompt"
  end

  test "current/0 falls back to Workflow.load/0 when GenServer is not running" do
    pid = Process.whereis(WorkflowStore)
    Process.unregister(WorkflowStore)
    assert Process.whereis(WorkflowStore) == nil

    {:ok, workflow} = WorkflowStore.current()
    Process.register(pid, WorkflowStore)

    assert workflow.prompt == "Initial Prompt"
  end

  test "force_reload/0 falls back to Workflow.load/0 when GenServer is not running and handles success" do
    pid = Process.whereis(WorkflowStore)
    Process.unregister(WorkflowStore)
    assert Process.whereis(WorkflowStore) == nil

    assert :ok = WorkflowStore.force_reload()

    Process.register(pid, WorkflowStore)
  end

  test "force_reload/0 falls back to Workflow.load/0 when GenServer is not running and handles error", %{workflow_file: workflow_file} do
    pid = Process.whereis(WorkflowStore)
    Process.unregister(WorkflowStore)
    assert Process.whereis(WorkflowStore) == nil

    File.write!(workflow_file, "---\ninvalid yaml\n---")
    assert {:error, :workflow_front_matter_not_a_map} = WorkflowStore.force_reload()

    Process.register(pid, WorkflowStore)
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

  test "handle_info(:poll, ...) handles errors by keeping the old state", %{workflow_file: workflow_file} do
    # Verify initial state
    {:ok, workflow} = WorkflowStore.current()
    assert workflow.prompt == "Initial Prompt"

    # Modify the file with invalid YAML to trigger an error in load_state
    File.write!(workflow_file, """
    ---
    invalid yaml
    ---
    """)

    # Manually trigger the :poll message
    send(Process.whereis(WorkflowStore), :poll)

    # We cannot directly observe the return value of handle_info, but we can verify
    # that the GenServer is still alive and serving the old configuration
    {:ok, old_workflow} = WorkflowStore.current()
    assert old_workflow.prompt == "Initial Prompt"
  end
end

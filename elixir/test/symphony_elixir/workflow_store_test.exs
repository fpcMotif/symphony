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

  test "current/0 falls back to direct load when GenServer is not running", %{workflow_file: workflow_file} do
    on_exit(fn ->
      write_workflow_file!(workflow_file, prompt: "Initial Prompt")
      _ = Supervisor.restart_child(SymphonyElixir.Supervisor, WorkflowStore)
    end)

    # Stop the GenServer
    :ok = Supervisor.terminate_child(SymphonyElixir.Supervisor, WorkflowStore)

    # Modify the file
    File.write!(workflow_file, """
    ---
    tracker:
      kind: "linear"
    ---
    Direct Load Prompt
    """)

    # current/0 should still work by bypassing the GenServer
    {:ok, new_workflow} = WorkflowStore.current()
    assert new_workflow.prompt == "Direct Load Prompt"
  end

  test "force_reload/0 falls back to direct load when GenServer is not running", %{workflow_file: workflow_file} do
    on_exit(fn ->
      write_workflow_file!(workflow_file, prompt: "Initial Prompt")
      _ = Supervisor.restart_child(SymphonyElixir.Supervisor, WorkflowStore)
    end)

    # Stop the GenServer
    :ok = Supervisor.terminate_child(SymphonyElixir.Supervisor, WorkflowStore)

    # Modify the file
    File.write!(workflow_file, """
    ---
    tracker:
      kind: "linear"
    ---
    Direct Force Reload Prompt
    """)

    # force_reload/0 should still return :ok by bypass the GenServer
    assert :ok = WorkflowStore.force_reload()

    {:ok, new_workflow} = WorkflowStore.current()
    assert new_workflow.prompt == "Direct Force Reload Prompt"
  end

  test "force_reload/0 returns {:error, reason} when GenServer is not running and workflow is invalid", %{workflow_file: workflow_file} do
    on_exit(fn ->
      write_workflow_file!(workflow_file, prompt: "Initial Prompt")
      _ = Supervisor.restart_child(SymphonyElixir.Supervisor, WorkflowStore)
    end)

    # Stop the GenServer
    :ok = Supervisor.terminate_child(SymphonyElixir.Supervisor, WorkflowStore)

    # Write invalid content
    File.write!(workflow_file, "---\ninvalid yaml\n---")

    # Force reload
    assert {:error, :workflow_front_matter_not_a_map} = WorkflowStore.force_reload()
  end

  test "init/1 returns {:stop, reason} when initial load fails", %{workflow_file: original_path} do
    on_exit(fn ->
      Application.put_env(:symphony_elixir, :workflow_file_path, original_path)
    end)

    # Use a non-existent file
    missing_path = "/tmp/does_not_exist_#{System.unique_integer([:positive])}.md"
    Application.put_env(:symphony_elixir, :workflow_file_path, missing_path)

    # init/1 should return {:stop, reason}
    assert {:stop, {:missing_workflow_file, ^missing_path, :enoent}} = WorkflowStore.init([])
  end

  test "handle_call(:current, ...) returns last known good workflow when reloading state fails", %{workflow_file: workflow_file} do
    # Write invalid content
    File.write!(workflow_file, "---\ninvalid yaml\n---")

    # Calling current/0 will try to reload and fail, returning the old workflow
    {:ok, new_workflow} = WorkflowStore.current()
    assert new_workflow.prompt == "Initial Prompt"
  end

  test "handle_info(:poll, ...) returns last known good state when reloading state fails", %{workflow_file: workflow_file} do
    # Write invalid content
    File.write!(workflow_file, "---\ninvalid yaml\n---")

    # Trigger poll
    send(Process.whereis(WorkflowStore), :poll)

    # Wait briefly to ensure the GenServer processes the message
    :timer.sleep(10)

    # Calling current/0 will still have the old workflow
    {:ok, new_workflow} = WorkflowStore.current()
    assert new_workflow.prompt == "Initial Prompt"
  end

  test "start_link/1 accepts options" do
    on_exit(fn ->
      _ = Supervisor.restart_child(SymphonyElixir.Supervisor, WorkflowStore)
    end)

    :ok = Supervisor.terminate_child(SymphonyElixir.Supervisor, WorkflowStore)
    assert {:ok, pid} = WorkflowStore.start_link([])
    assert is_pid(pid)
    GenServer.stop(pid)
  end

  test "start_link/0 starts with default options" do
    on_exit(fn ->
      _ = Supervisor.restart_child(SymphonyElixir.Supervisor, WorkflowStore)
    end)

    :ok = Supervisor.terminate_child(SymphonyElixir.Supervisor, WorkflowStore)
    assert {:ok, pid} = WorkflowStore.start_link()
    assert is_pid(pid)
    GenServer.stop(pid)
  end
end

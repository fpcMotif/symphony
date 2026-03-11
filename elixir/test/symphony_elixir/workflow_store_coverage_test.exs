defmodule SymphonyElixir.WorkflowStoreCoverageTest do
  use ExUnit.Case, async: false

  alias SymphonyElixir.Workflow
  alias SymphonyElixir.WorkflowStore

  import SymphonyElixir.TestSupport, only: [write_workflow_file!: 2]

  setup do
    workflow_root =
      Path.join(
        System.tmp_dir!(),
        "symphony-elixir-workflow-store-cov-test-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(workflow_root)
    workflow_file = Path.join(workflow_root, "WORKFLOW.md")

    write_workflow_file!(workflow_file, prompt: "Initial Prompt")

    # Store previous config to restore it
    prev_config = Application.get_env(:symphony_elixir, :workflow_file_path)
    Workflow.set_workflow_file_path(workflow_file)

    on_exit(fn ->
      if prev_config do
        Application.put_env(:symphony_elixir, :workflow_file_path, prev_config)
      else
        Application.delete_env(:symphony_elixir, :workflow_file_path)
      end
      File.rm_rf(workflow_root)
    end)

    %{workflow_file: workflow_file, workflow_root: workflow_root}
  end

  # Helpers to manage the global process safely
  defp stop_global_store do
    if Process.whereis(WorkflowStore) do
      try do
        Supervisor.terminate_child(SymphonyElixir.Supervisor, WorkflowStore)
        Process.sleep(10)
      rescue
        _ ->
          Process.unregister(WorkflowStore)
          # We don't need to kill it if we just unregister it for testing
      end
    end
  end

  defp ensure_global_store do
    if not is_pid(Process.whereis(WorkflowStore)) do
      try do
        Supervisor.restart_child(SymphonyElixir.Supervisor, WorkflowStore)
      rescue
        _ -> :ok # Let it be if we can't restart via supervisor
      end
      Process.sleep(10)
    end
  end

  test "start_link with opts" do
    stop_global_store()

    assert {:ok, pid} = WorkflowStore.start_link()
    assert is_pid(pid)

    GenServer.stop(pid)
    ensure_global_store()
  end

  test "init stops when file cannot be loaded" do
    stop_global_store()

    Application.put_env(:symphony_elixir, :workflow_file_path, "non-existent-path")

    # Catching the exit explicitly
    Process.flag(:trap_exit, true)

    assert {:error, {:missing_workflow_file, "non-existent-path", :enoent}} = WorkflowStore.start_link()

    ensure_global_store()
  end

  test "handle_info :poll preserves state on error", %{workflow_file: workflow_file} do
    ensure_global_store()

    # Write invalid content to cause an error during reload
    File.write!(workflow_file, "---\ninvalid yaml\n---")

    # We call the handler directly to ensure we exercise the error branch in handle_info
    state = :sys.get_state(WorkflowStore)

    # Verify handle_info returns noreply and preserves state when reloading fails
    assert {:noreply, ^state} = WorkflowStore.handle_info(:poll, state)
  end

  test "handle_call :current preserves state on error", %{workflow_file: workflow_file} do
    ensure_global_store()

    # Write invalid content to cause an error during reload
    File.write!(workflow_file, "---\ninvalid yaml\n---")

    state = :sys.get_state(WorkflowStore)

    # Verify handle_call returns the last known good workflow and preserves state
    assert {:reply, {:ok, workflow}, ^state} = WorkflowStore.handle_call(:current, self(), state)
    assert workflow.prompt == "Initial Prompt"
  end

  test "current/0 falls back to Workflow.load/0 when not running" do
    stop_global_store()

    # The process is definitely stopped or unregistered
    assert Process.whereis(WorkflowStore) == nil

    {:ok, workflow} = WorkflowStore.current()
    assert workflow.prompt == "Initial Prompt"

    ensure_global_store()
  end

  test "force_reload/0 falls back to Workflow.load/0 when not running" do
    stop_global_store()

    # The process is definitely stopped or unregistered
    assert Process.whereis(WorkflowStore) == nil

    assert :ok = WorkflowStore.force_reload()

    ensure_global_store()
  end

  test "force_reload/0 returns error from Workflow.load/0 when not running", %{workflow_file: workflow_file} do
    stop_global_store()

    # The process is definitely stopped or unregistered
    assert Process.whereis(WorkflowStore) == nil

    File.write!(workflow_file, "---\ninvalid yaml\n---")
    assert {:error, :workflow_front_matter_not_a_map} = WorkflowStore.force_reload()

    # Restore valid file using the helper before starting
    write_workflow_file!(workflow_file, prompt: "Restored Prompt")
    ensure_global_store()
  end
end

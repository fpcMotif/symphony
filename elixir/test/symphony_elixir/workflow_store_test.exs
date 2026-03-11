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

  describe "when GenServer is not running" do
    setup do
      # Stop the GenServer started in the main setup
      if pid = Process.whereis(WorkflowStore) do
        # GenServer might not be under a standard supervisor in tests if it was started manually
        try do
          GenServer.stop(WorkflowStore)
        catch
          :exit, _ -> Process.exit(pid, :kill)
        end

        # Ensure it's not registered
        if Process.whereis(WorkflowStore) do
          try do
            Process.unregister(WorkflowStore)
          catch
            _, _ -> :ok
          end
        end
      end

      :ok
    end

    test "current/0 loads from file directly", %{workflow_file: _workflow_file} do
      assert nil == Process.whereis(WorkflowStore)

      {:ok, workflow} = WorkflowStore.current()
      assert workflow.prompt == "Initial Prompt"
    end

    test "force_reload/0 loads from file directly and returns :ok", %{workflow_file: _workflow_file} do
      assert nil == Process.whereis(WorkflowStore)

      assert :ok = WorkflowStore.force_reload()

      {:ok, workflow} = WorkflowStore.current()
      assert workflow.prompt == "Initial Prompt"
    end

    test "force_reload/0 returns error if file is missing" do
      assert nil == Process.whereis(WorkflowStore)

      # Change the workflow file path to a non-existent file
      Workflow.set_workflow_file_path("/non/existent/path/WORKFLOW.md")

      assert {:error, {:missing_workflow_file, "/non/existent/path/WORKFLOW.md", :enoent}} = WorkflowStore.force_reload()
    end
  end

  describe "start_link/1 failures" do
    setup do
      # To test start_link/1 independently and cleanly, we should make sure the main test
      # supervisor isn't getting in the way
      # The main setup block calls `start_supervised!({WorkflowStore, []})` if it's not already running
      # Since `async: false` is used, the tests run sequentially.
      # Let's cleanly stop it using stop_supervised

      try do
        stop_supervised(WorkflowStore)
      catch
        _, _ -> :ok
      end

      # Also try stopping from the main application supervisor if it happens to be running there
      try do
        Supervisor.terminate_child(SymphonyElixir.Supervisor, WorkflowStore)
      catch
        _, _ -> :ok
      end

      pid = Process.whereis(WorkflowStore)

      if pid do
        try do
          Process.exit(pid, :kill)
        catch
          _, _ -> :ok
        end

        try do
          Process.unregister(WorkflowStore)
        catch
          _, _ -> :ok
        end
      end

      # Small sleep to ensure the KILL signal propagates
      :timer.sleep(10)

      # Make sure the supervisor doesn't bring it back immediately
      assert nil == Process.whereis(WorkflowStore)

      Process.flag(:trap_exit, true)

      on_exit(fn ->
        if Process.whereis(WorkflowStore) do
          try do
            Process.unregister(WorkflowStore)
          catch
            _, _ -> :ok
          end
        end
      end)

      :ok
    end

    test "fails to start if workflow file is missing" do
      Workflow.set_workflow_file_path("/non/existent/path/WORKFLOW.md")

      assert {:error, {:missing_workflow_file, "/non/existent/path/WORKFLOW.md", :enoent}} = WorkflowStore.start_link()
    end

    test "fails to start if workflow file is invalid", %{workflow_file: workflow_file} do
      File.write!(workflow_file, "---\ninvalid yaml\n---")

      assert {:error, :workflow_front_matter_not_a_map} = WorkflowStore.start_link()
    end
  end

  describe "polling behavior" do
    test "polls for changes automatically and handles invalid state", %{workflow_file: workflow_file} do
      # Verify initial state
      {:ok, workflow} = WorkflowStore.current()
      assert workflow.prompt == "Initial Prompt"

      # Modify the file to be invalid
      File.write!(workflow_file, "---\ninvalid yaml\n---")

      # Manually trigger the :poll message that the GenServer schedules for itself
      send(Process.whereis(WorkflowStore), :poll)

      # Wait a tiny bit for the message to be processed
      :timer.sleep(10)

      # Calling `current/0` should still return the old state
      {:ok, workflow_after_error} = WorkflowStore.current()
      assert workflow_after_error.prompt == "Initial Prompt"
    end
  end
end

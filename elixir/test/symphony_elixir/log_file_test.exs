defmodule SymphonyElixir.LogFileTest do
  use ExUnit.Case, async: false

  alias SymphonyElixir.LogFile

  setup do
    # Save current handlers
    current_handlers = :logger.get_handler_config()

    on_exit(fn ->
      # Remove :symphony_disk_log if added
      :logger.remove_handler(:symphony_disk_log)

      # Restore original handlers
      for handler <- current_handlers do
        :logger.add_handler(handler.id, handler.module, handler)
      end
    end)

    :ok
  end

  test "default_log_file/0 uses the current working directory" do
    assert LogFile.default_log_file() == Path.join(File.cwd!(), "log/symphony.log")
  end

  test "default_log_file/1 builds the log path under a custom root" do
    assert LogFile.default_log_file("/tmp/symphony-logs") == "/tmp/symphony-logs/log/symphony.log"
  end

  test "configure/0 sets up the disk log handler and removes default console handler" do
    # Ensure default is present before configuring
    if match?({:error, _}, :logger.get_handler_config(:default)) do
      :logger.add_handler(:default, :logger_std_h, %{})
    end

    assert {:ok, _} = :logger.get_handler_config(:default)

    assert :ok = LogFile.configure()

    # Check that :symphony_disk_log handler is added
    assert {:ok, handler_config} = :logger.get_handler_config(:symphony_disk_log)

    assert handler_config.module == :logger_disk_log_h
    assert handler_config.config.type == :wrap
    assert handler_config.config.max_no_bytes == 10 * 1024 * 1024
    assert handler_config.config.max_no_files == 5

    expected_path = LogFile.default_log_file() |> Path.expand() |> String.to_charlist()
    assert handler_config.config.file == expected_path

    # Check that default console handler is removed
    assert {:error, {:not_found, :default}} = :logger.get_handler_config(:default)
  end

  test "configure/0 uses custom config values from Application env" do
    custom_dir = Path.join(System.tmp_dir!(), "symphony-log-test-#{System.unique_integer([:positive])}")
    custom_path = Path.join(custom_dir, "custom.log")

    Application.put_env(:symphony_elixir, :log_file, custom_path)
    Application.put_env(:symphony_elixir, :log_file_max_bytes, 5_000_000)
    Application.put_env(:symphony_elixir, :log_file_max_files, 3)

    on_exit(fn ->
      Application.delete_env(:symphony_elixir, :log_file)
      Application.delete_env(:symphony_elixir, :log_file_max_bytes)
      Application.delete_env(:symphony_elixir, :log_file_max_files)
      File.rm_rf(custom_dir)
    end)

    assert :ok = LogFile.configure()

    {:ok, handler_config} = :logger.get_handler_config(:symphony_disk_log)
    assert handler_config.config.max_no_bytes == 5_000_000
    assert handler_config.config.max_no_files == 3

    expected_path = Path.expand(custom_path) |> String.to_charlist()
    assert handler_config.config.file == expected_path
  end

  test "configure/0 is idempotent (can be called multiple times)" do
    assert :ok = LogFile.configure()
    assert :ok = LogFile.configure()

    {:ok, handler_config} = :logger.get_handler_config(:symphony_disk_log)
    assert handler_config.module == :logger_disk_log_h
  end

  test "configure/0 handles handler setup failure gracefully" do
    # Use invalid max_no_bytes to trigger handler error
    Application.put_env(:symphony_elixir, :log_file_max_bytes, -1)

    on_exit(fn ->
      Application.delete_env(:symphony_elixir, :log_file_max_bytes)
    end)

    # Should not raise, should log a warning and return :ok
    assert :ok = LogFile.configure()
  end
end

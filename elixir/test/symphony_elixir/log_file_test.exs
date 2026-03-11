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

  test "configure/0 reads custom values from Application environment" do
    custom_path = "/tmp/custom-symphony.log"
    custom_max_bytes = 20 * 1024 * 1024
    custom_max_files = 10

    # Ensure default is present before configuring
    if match?({:error, _}, :logger.get_handler_config(:default)) do
      :logger.add_handler(:default, :logger_std_h, %{})
    end

    Application.put_env(:symphony_elixir, :log_file, custom_path)
    Application.put_env(:symphony_elixir, :log_file_max_bytes, custom_max_bytes)
    Application.put_env(:symphony_elixir, :log_file_max_files, custom_max_files)

    on_exit(fn ->
      Application.delete_env(:symphony_elixir, :log_file)
      Application.delete_env(:symphony_elixir, :log_file_max_bytes)
      Application.delete_env(:symphony_elixir, :log_file_max_files)
    end)

    assert :ok = LogFile.configure()

    assert {:ok, handler_config} = :logger.get_handler_config(:symphony_disk_log)

    assert handler_config.module == :logger_disk_log_h
    assert handler_config.config.type == :wrap
    assert handler_config.config.max_no_bytes == custom_max_bytes
    assert handler_config.config.max_no_files == custom_max_files

    expected_path = custom_path |> Path.expand() |> String.to_charlist()
    assert handler_config.config.file == expected_path
  end

  test "configure/0 is idempotent (handles removing existing handler gracefully)" do
    # Configure once
    assert :ok = LogFile.configure()
    assert {:ok, _} = :logger.get_handler_config(:symphony_disk_log)

    # Configure again
    assert :ok = LogFile.configure()
    assert {:ok, _} = :logger.get_handler_config(:symphony_disk_log)
  end

  test "configure/0 gracefully handles errors and logs a warning when invalid parameters are supplied" do
    import ExUnit.CaptureLog

    # Provide an invalid type (string instead of integer) to force add_handler to fail
    Application.put_env(:symphony_elixir, :log_file_max_bytes, "invalid")

    on_exit(fn ->
      Application.delete_env(:symphony_elixir, :log_file_max_bytes)
    end)

    log_output = capture_log(fn ->
      assert :ok = LogFile.configure()
    end)

    assert log_output =~ "Failed to configure rotating log file handler:"
  end
end

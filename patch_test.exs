defmodule SymphonyElixir.LogFilePatchTest do
  use ExUnit.Case, async: false
  alias SymphonyElixir.LogFile

  setup do
    current_handlers = :logger.get_handler_config()
    on_exit(fn ->
      :logger.remove_handler(:symphony_disk_log)
      for handler <- current_handlers do
        :logger.add_handler(handler.id, handler.module, handler)
      end
    end)
    :ok
  end

  test "configure/0 uses custom Application configuration when provided" do
    # Save current config
    orig_log_file = Application.get_env(:symphony_elixir, :log_file)
    orig_max_bytes = Application.get_env(:symphony_elixir, :log_file_max_bytes)
    orig_max_files = Application.get_env(:symphony_elixir, :log_file_max_files)

    on_exit(fn ->
      if orig_log_file, do: Application.put_env(:symphony_elixir, :log_file, orig_log_file), else: Application.delete_env(:symphony_elixir, :log_file)
      if orig_max_bytes, do: Application.put_env(:symphony_elixir, :log_file_max_bytes, orig_max_bytes), else: Application.delete_env(:symphony_elixir, :log_file_max_bytes)
      if orig_max_files, do: Application.put_env(:symphony_elixir, :log_file_max_files, orig_max_files), else: Application.delete_env(:symphony_elixir, :log_file_max_files)
    end)

    custom_path = "/tmp/custom_symphony_test.log"
    Application.put_env(:symphony_elixir, :log_file, custom_path)
    Application.put_env(:symphony_elixir, :log_file_max_bytes, 1024)
    Application.put_env(:symphony_elixir, :log_file_max_files, 2)

    assert :ok = LogFile.configure()

    assert {:ok, handler_config} = :logger.get_handler_config(:symphony_disk_log)
    assert handler_config.config.file == String.to_charlist(custom_path)
    assert handler_config.config.max_no_bytes == 1024
    assert handler_config.config.max_no_files == 2
  end

  test "configure/0 handles :logger.add_handler error gracefully" do
    import ExUnit.CaptureLog

    # Save current config
    orig_max_files = Application.get_env(:symphony_elixir, :log_file_max_files)

    on_exit(fn ->
      if orig_max_files, do: Application.put_env(:symphony_elixir, :log_file_max_files, orig_max_files), else: Application.delete_env(:symphony_elixir, :log_file_max_files)
    end)

    # Provide an invalid max_files to trigger a validation error in logger_disk_log_h
    Application.put_env(:symphony_elixir, :log_file_max_files, -1)

    log = capture_log(fn ->
      assert :ok = LogFile.configure()
    end)

    assert log =~ "Failed to configure rotating log file handler:"
  end
end

defmodule SymphonyElixir.PathSafetyTest do
  use ExUnit.Case, async: true
  alias SymphonyElixir.PathSafety

  @moduletag :tmp_dir

  describe "canonicalize/1" do
    test "returns absolute path for existing file", %{tmp_dir: tmp_dir} do
      file_path = Path.join(tmp_dir, "file.txt")
      File.write!(file_path, "content")

      assert {:ok, ^file_path} = PathSafety.canonicalize(file_path)
    end

    test "returns absolute path for existing directory", %{tmp_dir: tmp_dir} do
      dir_path = Path.join(tmp_dir, "dir")
      File.mkdir!(dir_path)

      assert {:ok, ^dir_path} = PathSafety.canonicalize(dir_path)
    end

    test "returns absolute path for non-existent path", %{tmp_dir: tmp_dir} do
      missing_path = Path.join(tmp_dir, "missing.txt")
      assert {:ok, ^missing_path} = PathSafety.canonicalize(missing_path)
    end

    test "resolves symlink to a file", %{tmp_dir: tmp_dir} do
      target_file = Path.join(tmp_dir, "target.txt")
      symlink_file = Path.join(tmp_dir, "symlink.txt")

      File.write!(target_file, "content")
      File.ln_s!(target_file, symlink_file)

      assert {:ok, ^target_file} = PathSafety.canonicalize(symlink_file)
    end

    test "resolves symlink to a directory", %{tmp_dir: tmp_dir} do
      target_dir = Path.join(tmp_dir, "target_dir")
      symlink_dir = Path.join(tmp_dir, "symlink_dir")

      File.mkdir!(target_dir)
      File.ln_s!(target_dir, symlink_dir)

      assert {:ok, ^target_dir} = PathSafety.canonicalize(symlink_dir)
    end

    test "resolves nested symlinks", %{tmp_dir: tmp_dir} do
      target_file = Path.join(tmp_dir, "target.txt")
      symlink_1 = Path.join(tmp_dir, "symlink_1.txt")
      symlink_2 = Path.join(tmp_dir, "symlink_2.txt")

      File.write!(target_file, "content")
      File.ln_s!(target_file, symlink_1)
      File.ln_s!(symlink_1, symlink_2)

      assert {:ok, ^target_file} = PathSafety.canonicalize(symlink_2)
    end

    test "resolves relative symlink segments", %{tmp_dir: tmp_dir} do
      # Set up structure: tmp_dir/a/b/target.txt, tmp_dir/a/c/symlink.txt -> ../b/target.txt
      a_dir = Path.join(tmp_dir, "a")
      b_dir = Path.join(a_dir, "b")
      c_dir = Path.join(a_dir, "c")
      target_file = Path.join(b_dir, "target.txt")
      symlink_file = Path.join(c_dir, "symlink.txt")

      File.mkdir_p!(b_dir)
      File.mkdir_p!(c_dir)
      File.write!(target_file, "content")
      File.ln_s!("../b/target.txt", symlink_file)

      assert {:ok, ^target_file} = PathSafety.canonicalize(symlink_file)
    end

    test "handles deeply nested non-existent path", %{tmp_dir: tmp_dir} do
      missing_path = Path.join([tmp_dir, "a", "b", "c", "missing.txt"])
      assert {:ok, ^missing_path} = PathSafety.canonicalize(missing_path)
    end

    test "returns error for circular symlinks", %{tmp_dir: tmp_dir} do
      symlink_1 = Path.join(tmp_dir, "symlink_1.txt")
      symlink_2 = Path.join(tmp_dir, "symlink_2.txt")

      File.ln_s!(symlink_2, symlink_1)
      File.ln_s!(symlink_1, symlink_2)

      assert {:error, {:path_canonicalize_failed, ^symlink_1, :eloop}} = PathSafety.canonicalize(symlink_1)
    end

    test "returns error when file permissions prevent stat", %{tmp_dir: tmp_dir} do
      # Create a directory without read permissions to trigger an error when accessing a child
      dir_path = Path.join(tmp_dir, "no_access_dir")
      file_path = Path.join(dir_path, "file.txt")

      File.mkdir!(dir_path)
      File.write!(file_path, "content")

      # Remove execute (and read) permissions on the directory
      File.chmod!(dir_path, 0o000)

      on_exit(fn ->
        # Restore permissions so cleanup works
        File.chmod!(dir_path, 0o777)
      end)

      # Attempting to lstat the file inside should fail with :eacces
      assert {:error, {:path_canonicalize_failed, ^file_path, :eacces}} = PathSafety.canonicalize(file_path)
    end
  end
end

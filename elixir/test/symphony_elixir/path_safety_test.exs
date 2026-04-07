defmodule SymphonyElixir.PathSafetyTest do
  use ExUnit.Case, async: false

  alias SymphonyElixir.PathSafety

  @moduletag :tmp_dir

  describe "canonicalize/1" do
    test "resolves a normal absolute path", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "normal_file.txt")
      File.write!(path, "content")

      assert {:ok, canonical} = PathSafety.canonicalize(path)
      assert canonical == Path.expand(path)
    end

    test "resolves a path that does not exist", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "missing_file.txt")

      assert {:ok, canonical} = PathSafety.canonicalize(path)
      assert canonical == Path.expand(path)
    end

    test "resolves a path containing a relative symlink", %{tmp_dir: tmp_dir} do
      target_path = Path.join(tmp_dir, "target.txt")
      File.write!(target_path, "content")

      link_path = Path.join(tmp_dir, "link.txt")
      File.ln_s!("target.txt", link_path)

      assert {:ok, canonical} = PathSafety.canonicalize(link_path)
      assert canonical == Path.expand(target_path)
    end

    test "resolves a path containing an absolute symlink", %{tmp_dir: tmp_dir} do
      target_path = Path.join(tmp_dir, "target.txt")
      File.write!(target_path, "content")

      link_path = Path.join(tmp_dir, "link.txt")
      File.ln_s!(target_path, link_path)

      assert {:ok, canonical} = PathSafety.canonicalize(link_path)
      assert canonical == Path.expand(target_path)
    end

    test "resolves a path containing a symlinked directory", %{tmp_dir: tmp_dir} do
      target_dir = Path.join(tmp_dir, "target_dir")
      File.mkdir!(target_dir)

      target_file = Path.join(target_dir, "file.txt")
      File.write!(target_file, "content")

      link_dir = Path.join(tmp_dir, "link_dir")
      File.ln_s!(target_dir, link_dir)

      path_via_link = Path.join(link_dir, "file.txt")

      assert {:ok, canonical} = PathSafety.canonicalize(path_via_link)
      assert canonical == Path.expand(target_file)
    end

    test "resolves complex nested symlinks", %{tmp_dir: tmp_dir} do
      # tmp_dir/a/b/c/target.txt
      dir_c = Path.join([tmp_dir, "a", "b", "c"])
      File.mkdir_p!(dir_c)

      target_file = Path.join(dir_c, "target.txt")
      File.write!(target_file, "content")

      # link 1: tmp_dir/link_to_c -> tmp_dir/a/b/c
      link_to_c = Path.join(tmp_dir, "link_to_c")
      File.ln_s!(dir_c, link_to_c)

      # link 2: tmp_dir/link_to_link -> tmp_dir/link_to_c
      link_to_link = Path.join(tmp_dir, "link_to_link")
      File.ln_s!(link_to_c, link_to_link)

      path_via_links = Path.join(link_to_link, "target.txt")

      assert {:ok, canonical} = PathSafety.canonicalize(path_via_links)
      assert canonical == Path.expand(target_file)
    end
  end

  describe "canonicalize/1 error cases" do
    test "returns error when file system stat fails due to permissions", %{tmp_dir: tmp_dir} do
      restricted_dir = Path.join(tmp_dir, "restricted")
      File.mkdir!(restricted_dir)

      file_in_restricted = Path.join(restricted_dir, "file.txt")
      File.write!(file_in_restricted, "content")

      # Remove execute permission from directory so we can't stat contents
      File.chmod!(restricted_dir, 0o000)

      on_exit(fn ->
        File.chmod!(restricted_dir, 0o755)
      end)

      assert {:error, {:path_canonicalize_failed, _expanded_path, :eacces}} =
               PathSafety.canonicalize(file_in_restricted)
    end
  end
end

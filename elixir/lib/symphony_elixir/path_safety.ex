defmodule SymphonyElixir.PathSafety do
  @moduledoc false
  @max_symlink_resolutions 64

  @spec canonicalize(Path.t()) :: {:ok, Path.t()} | {:error, term()}
  def canonicalize(path) when is_binary(path) do
    expanded_path = Path.expand(path)
    {root, segments} = split_absolute_path(expanded_path)

    case resolve_segments(root, [], segments, @max_symlink_resolutions) do
      {:ok, canonical_path} ->
        {:ok, canonical_path}

      {:error, reason} ->
        {:error, {:path_canonicalize_failed, expanded_path, reason}}
    end
  end

  defp split_absolute_path(path) when is_binary(path) do
    [root | segments] = Path.split(path)
    {root, segments}
  end

  defp resolve_segments(root, resolved_segments, [], _remaining_symlink_resolutions),
    do: {:ok, join_path(root, resolved_segments)}

  defp resolve_segments(root, resolved_segments, [segment | rest], remaining_symlink_resolutions) do
    candidate_path = join_path(root, resolved_segments ++ [segment])

    case File.lstat(candidate_path) do
      {:ok, %File.Stat{type: :symlink}} ->
        follow_symlink(candidate_path, root, resolved_segments, rest, remaining_symlink_resolutions)

      {:ok, _stat} ->
        resolve_segments(root, resolved_segments ++ [segment], rest, remaining_symlink_resolutions)

      {:error, :enoent} ->
        {:ok, join_path(root, resolved_segments ++ [segment | rest])}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp follow_symlink(_candidate_path, _root, _resolved_segments, _rest, remaining_symlink_resolutions)
       when remaining_symlink_resolutions <= 0 do
    {:error, :symlink_loop}
  end

  defp follow_symlink(candidate_path, root, resolved_segments, rest, remaining_symlink_resolutions) do
    with {:ok, target} <- :file.read_link_all(String.to_charlist(candidate_path)) do
      resolved_target = Path.expand(IO.chardata_to_string(target), join_path(root, resolved_segments))
      {target_root, target_segments} = split_absolute_path(resolved_target)
      resolve_segments(target_root, [], target_segments ++ rest, remaining_symlink_resolutions - 1)
    end
  end

  defp join_path(root, segments) when is_list(segments) do
    Enum.reduce(segments, root, fn segment, acc -> Path.join(acc, segment) end)
  end
end

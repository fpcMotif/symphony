defmodule SymphonyElixir.TokenExtractor do
  @moduledoc """
  Centralized token extraction logic for Codex usage metadata.
  """

  @input_keys [
    "input_tokens",
    :input_tokens,
    "prompt_tokens",
    :prompt_tokens,
    "inputTokens",
    :inputTokens,
    "promptTokens",
    :promptTokens,
    :input
  ]

  @output_keys [
    "output_tokens",
    :output_tokens,
    "completion_tokens",
    :completion_tokens,
    "outputTokens",
    :outputTokens,
    "completionTokens",
    :completionTokens,
    :output,
    :completion
  ]

  @total_keys [
    "total_tokens",
    :total_tokens,
    "total",
    :total,
    "totalTokens",
    :totalTokens
  ]

  @all_keys @input_keys ++ @output_keys ++ @total_keys

  @doc """
  Extracts input tokens from a usage map.
  """
  @spec extract_input(map() | nil) :: integer() | nil
  def extract_input(usage), do: extract_value(usage, @input_keys)

  @doc """
  Extracts output tokens from a usage map.
  """
  @spec extract_output(map() | nil) :: integer() | nil
  def extract_output(usage), do: extract_value(usage, @output_keys)

  @doc """
  Extracts total tokens from a usage map.
  """
  @spec extract_total(map() | nil) :: integer() | nil
  def extract_total(usage), do: extract_value(usage, @total_keys)

  @doc """
  Returns true if the given map contains any recognized token keys with integer-like values.
  """
  @spec token_map?(any()) :: boolean()
  def token_map?(usage) when is_map(usage) do
    Enum.any?(@all_keys, fn key ->
      !is_nil(parse_integer(Map.get(usage, key)))
    end)
  end

  def token_map?(_), do: false

  defp extract_value(usage, keys) when is_map(usage) do
    Enum.find_value(keys, fn key ->
      parse_integer(Map.get(usage, key))
    end)
  end

  defp extract_value(_, _), do: nil

  defp parse_integer(value) when is_integer(value), do: value

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp parse_integer(_value), do: nil
end

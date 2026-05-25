defmodule SymphonyElixir.WorkflowTest do
  use ExUnit.Case, async: true

  alias SymphonyElixir.Workflow

  describe "load/1" do
    test "returns error when file does not exist" do
      non_existent_path = "path/to/non_existent_file_#{System.unique_integer([:positive])}.yml"

      assert {:error, {:missing_workflow_file, ^non_existent_path, :enoent}} =
               Workflow.load(non_existent_path)
    end
  end
end

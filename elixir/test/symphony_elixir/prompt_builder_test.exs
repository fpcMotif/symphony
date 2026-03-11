defmodule SymphonyElixir.PromptBuilderTest do
  use SymphonyElixir.TestSupport

  describe "build_prompt/2" do
    test "renders issue fields into prompt template via Liquid syntax" do
      write_workflow_file!(Workflow.workflow_file_path(),
        prompt: "Fix issue {{ issue.identifier }}: {{ issue.title }}\nDescription: {{ issue.description }}"
      )

      issue = %Issue{
        id: "issue-pb-1",
        identifier: "PRJ-100",
        title: "Fix the login bug",
        description: "Login fails on mobile",
        state: "In Progress"
      }

      prompt = PromptBuilder.build_prompt(issue)

      assert prompt =~ "Fix issue PRJ-100: Fix the login bug"
      assert prompt =~ "Description: Login fails on mobile"
    end

    test "renders with attempt option available" do
      write_workflow_file!(Workflow.workflow_file_path(),
        prompt: "Attempt: {{ attempt }}, Issue: {{ issue.title }}"
      )

      issue = %Issue{id: "issue-pb-2", identifier: "PRJ-101", title: "Test attempt"}

      prompt = PromptBuilder.build_prompt(issue, attempt: 3)
      assert prompt =~ "Attempt: 3"
      assert prompt =~ "Issue: Test attempt"
    end

    test "converts DateTime fields to ISO8601 strings in template" do
      write_workflow_file!(Workflow.workflow_file_path(),
        prompt: "Created: {{ issue.created_at }}"
      )

      issue = %Issue{
        id: "issue-pb-3",
        identifier: "PRJ-102",
        title: "Datetime test",
        created_at: ~U[2025-06-15 10:30:00Z]
      }

      prompt = PromptBuilder.build_prompt(issue)
      assert prompt =~ "2025-06-15T10:30:00Z"
    end

    test "renders labels as a list" do
      write_workflow_file!(Workflow.workflow_file_path(),
        prompt: "Labels: {% for label in issue.labels %}{{ label }} {% endfor %}"
      )

      issue = %Issue{
        id: "issue-pb-4",
        identifier: "PRJ-103",
        title: "Labels test",
        labels: ["bug", "frontend"]
      }

      prompt = PromptBuilder.build_prompt(issue)
      assert prompt =~ "bug"
      assert prompt =~ "frontend"
    end

    test "falls back to Config.workflow_prompt when template is empty" do
      write_workflow_file!(Workflow.workflow_file_path(), prompt: "   ")

      issue = %Issue{id: "issue-pb-5", identifier: "PRJ-104", title: "Empty template"}

      prompt = PromptBuilder.build_prompt(issue)
      assert is_binary(prompt)
      assert String.trim(prompt) != ""
    end

    test "raises on invalid Liquid template syntax" do
      write_workflow_file!(Workflow.workflow_file_path(),
        prompt: "{% invalid_tag %}"
      )

      issue = %Issue{id: "issue-pb-6", identifier: "PRJ-105", title: "Bad template"}

      assert_raise RuntimeError, ~r/template_parse_error/, fn ->
        PromptBuilder.build_prompt(issue)
      end
    end

    test "handles nil description gracefully" do
      write_workflow_file!(Workflow.workflow_file_path(),
        prompt: "Title: {{ issue.title }}"
      )

      issue = %Issue{
        id: "issue-pb-7",
        identifier: "PRJ-106",
        title: "Nil description",
        description: nil
      }

      prompt = PromptBuilder.build_prompt(issue)
      assert prompt =~ "Title: Nil description"
    end

    test "renders blocked_by list items" do
      write_workflow_file!(Workflow.workflow_file_path(),
        prompt: "Blockers: {% for b in issue.blocked_by %}{{ b.identifier }} {% endfor %}"
      )

      issue = %Issue{
        id: "issue-pb-8",
        identifier: "PRJ-107",
        title: "Blocked issue",
        blocked_by: [
          %{id: "b1", identifier: "PRJ-50", state: "In Progress"},
          %{id: "b2", identifier: "PRJ-51", state: "Todo"}
        ]
      }

      prompt = PromptBuilder.build_prompt(issue)
      assert prompt =~ "PRJ-50"
      assert prompt =~ "PRJ-51"
    end
  end
end

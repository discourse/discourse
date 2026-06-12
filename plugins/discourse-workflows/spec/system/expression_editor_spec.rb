# frozen_string_literal: true

RSpec.describe "Workflow Expression Editor" do
  fab!(:admin)

  let(:editor_page) { PageObjects::Pages::DiscourseWorkflows::WorkflowEditor.new }
  let(:expression_editor) { PageObjects::Pages::DiscourseWorkflows::ExpressionEditor.new }

  before { sign_in(admin) }

  def open_create_post_configurator
    editor_page.visit_new
    editor_page.click_empty_state_add_node
    editor_page.select_node_type("trigger:topic_created")
    editor_page.click_add_node
    editor_page.select_node_type("action:post", operation: "create")
    editor_page.double_click_node(1)
  end

  def open_expression_editor
    open_create_post_configurator
    expression_editor.switch_to_expression_mode
  end

  context "when editing a node with expression fields" do
    before { open_expression_editor }

    it "shows the CodeMirror editor in expression mode" do
      expect(expression_editor).to have_expression_editor
    end

    it "shows dollar variable completions on Ctrl+Space" do
      expression_editor.type_in_editor("{{ ")
      expression_editor.trigger_autocomplete

      expect(expression_editor).to have_autocomplete_dropdown
      expect(expression_editor).to have_autocomplete_option("$json")
      expect(expression_editor).to have_autocomplete_option("$execution")
      expect(expression_editor).to have_autocomplete_option("$vars")
    end

    it "shows completions when typing $ inside expression braces" do
      expression_editor.type_in_editor("{{ $")

      expect(expression_editor).to have_autocomplete_dropdown
      expect(expression_editor).to have_autocomplete_option("$json")
      expect(expression_editor).to have_autocomplete_option("$vars")
    end

    it "auto-closes {{ }} and triggers completions" do
      expression_editor.type_in_editor("{{")

      expect(expression_editor).to have_autocomplete_dropdown
    end

    it "shows global completions for Math, JSON, etc." do
      expression_editor.type_in_editor("{{ Ma")

      expect(expression_editor).to have_autocomplete_dropdown
      expect(expression_editor).to have_autocomplete_option("Math")
    end

    it "marks unclosed expressions with error decoration" do
      expression_editor.type_in_editor("{{ $json.title")
      expression_editor.move_cursor_and_delete(3, 2)

      expect(expression_editor).to have_syntax_error
    end

    it "removes error decoration when expression is closed" do
      expression_editor.type_in_editor("{{ $json.title")

      expect(expression_editor).to have_no_syntax_error
    end

    it "applies syntax highlighting to expression braces" do
      expression_editor.type_in_editor("{{ $json.title")

      expect(expression_editor).to have_syntax_highlight("cm-wf-brace")
    end
  end

  context "when typing in expression mode" do
    before { open_expression_editor }

    it "updates the field value as the user types" do
      expression_editor.type_in_editor("hello world")

      text = expression_editor.editor_text
      expect(text).to include("hello world")
    end
  end

  context "with workflow variables" do
    fab!(:variable) { Fabricate(:discourse_workflows_variable, key: "API_KEY", value: "secret123") }

    before { open_expression_editor }

    it "shows $vars in completions" do
      expression_editor.type_in_editor("{{ $v")

      expect(expression_editor).to have_autocomplete_dropdown
      expect(expression_editor).to have_autocomplete_option("$vars")
    end
  end

  context "with hover tooltips" do
    before { open_expression_editor }

    it "shows a tooltip when hovering over a dollar variable" do
      expression_editor.type_in_editor("{{ $json }}")

      expression_editor.hover_variable("$json")

      expect(expression_editor).to have_hover_tooltip
      expect(expression_editor.hover_tooltip_text).to include("current input item")
    end
  end

  context "with expression preview" do
    before { open_expression_editor }

    it "shows a resolved preview below the editor" do
      expression_editor.type_in_editor("{{ $current_user.username }}")

      expect(expression_editor).to have_expression_preview
      expect(expression_editor).to have_expression_preview_result("valid", text: admin.username)
    end

    it "shows invalid JavaScript for bad expressions" do
      expression_editor.type_in_editor("{{ $vars. }}")

      expect(expression_editor).to have_expression_preview
      expect(expression_editor).to have_expression_preview_result(
        "invalid",
        text: "Invalid JavaScript",
      )
    end

    it "shows plain text result for non-expression content" do
      expression_editor.type_in_editor("Hello world")

      expect(expression_editor).to have_expression_preview
      expect(expression_editor).to have_expression_preview_plaintext("Hello world")
    end

    it "shows function warning when a method is referenced without calling it" do
      expression_editor.type_in_editor("{{ $current_user.username.includes }}")

      expect(expression_editor).to have_expression_preview
      expect(expression_editor).to have_expression_preview_result(
        "warning",
        text: "Missing function call",
      )
    end

    it "highlights invalid expressions in the editor with red background" do
      expression_editor.type_in_editor("{{ $vars. }}")

      expect(page).to have_css(".cm-wf-invalid-expression", wait: 10)
    end
  end

  context "with property access completions" do
    before { open_expression_editor }

    it "shows field completions after $execution." do
      expression_editor.type_in_editor("{{ $execution.")

      expect(expression_editor).to have_autocomplete_dropdown
      expect(expression_editor).to have_autocomplete_option("id")
      expect(expression_editor).to have_autocomplete_option("workflow_id")
    end

    it "shows static method completions for global objects" do
      expression_editor.type_in_editor("{{ Object.")

      expect(expression_editor).to have_autocomplete_dropdown
      expect(expression_editor).to have_autocomplete_option("keys")
      expect(expression_editor).to have_autocomplete_option("values")
    end
  end
end

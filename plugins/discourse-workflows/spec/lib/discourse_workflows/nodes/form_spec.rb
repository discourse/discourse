# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Form::V1 do
  let(:sandbox) { DiscourseWorkflows::JsSandbox.new({ "$json" => {} }) }
  after { sandbox.dispose }

  def build_exec_ctx(configuration, resume_token: nil)
    DiscourseWorkflows::Executor::NodeExecutionContext.new(
      input_items: [{ "json" => {} }],
      parameters: configuration,
      property_schema: described_class.property_schema,
      node_context: {
      },
      resolver: DiscourseWorkflows::ExpressionResolver.new({ "$json" => {} }, sandbox: sandbox),
      resume_token: resume_token,
    )
  end

  describe "#execute" do
    it "returns input items for non-completion forms" do
      config = {
        "form_title" => "Approval",
        "form_description" => "Please approve",
        "form_fields" => [{ "field_label" => "Reason", "field_type" => "text" }],
      }
      exec_ctx = build_exec_ctx(config, resume_token: "tok-xyz")

      result = described_class.new(parameters: config).execute(exec_ctx)

      expect(result).to eq([exec_ctx.input_items])
    end

    it "passes completion forms through without reaching into flow context" do
      config = {
        "page_type" => "completion",
        "on_submission" => "completion_screen",
        "completion_title" => "Done",
      }
      exec_ctx = build_exec_ctx(config, resume_token: "tok-xyz")

      result = described_class.new(parameters: config).execute(exec_ctx)

      expect(result).to eq([exec_ctx.input_items])
    end
  end
end

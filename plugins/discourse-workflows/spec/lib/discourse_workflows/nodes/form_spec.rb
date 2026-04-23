# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Form::V1 do
  let(:sandbox) { DiscourseWorkflows::JsSandbox.new({ "$json" => {} }) }
  after { sandbox.dispose }

  def build_exec_ctx(configuration, resume_token: nil)
    DiscourseWorkflows::Executor::NodeExecutionContext.new(
      input_items: [{ "json" => {} }],
      configuration: configuration,
      property_schema: described_class.property_schema,
      node_context: {
      },
      resolver: DiscourseWorkflows::ExpressionResolver.new({ "$json" => {} }, sandbox: sandbox),
      resume_token: resume_token,
    )
  end

  describe "#execute" do
    it "signals a wait via exec_ctx for non-completion forms" do
      config = {
        "form_title" => "Approval",
        "form_description" => "Please approve",
        "form_fields" => [{ "field_label" => "Reason", "field_type" => "text" }],
      }
      exec_ctx = build_exec_ctx(config, resume_token: "tok-xyz")
      allow(MessageBus).to receive(:publish)

      result = described_class.new(configuration: config).execute(exec_ctx)

      expect(exec_ctx).to be_waiting
      expect(exec_ctx.waiting_until).to be_nil
      expect(result).to eq([exec_ctx.input_items])
    end
  end
end

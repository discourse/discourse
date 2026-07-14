# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Wait::V1 do
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

  describe ".capabilities" do
    it "marks the node as not producing data" do
      expect(described_class.capabilities).to include(produces_data: false)
    end
  end

  describe "#execute" do
    it "returns input items for interval mode" do
      config = { "resume" => "time_interval", "wait_amount" => 2, "wait_unit" => "hours" }
      exec_ctx = build_exec_ctx(config)

      result = described_class.new(parameters: config).execute(exec_ctx)

      expect(result.first).to eq(exec_ctx.input_items)
    end

    it "returns input items for webhook mode" do
      config = { "resume" => "webhook" }
      exec_ctx = build_exec_ctx(config, resume_token: "tok-abc")

      result = described_class.new(parameters: config).execute(exec_ctx)

      expect(result.first).to eq(exec_ctx.input_items)
    end

    it "returns input items for bounded webhook waits" do
      config = {
        "resume" => "webhook",
        "limit_wait_time" => true,
        "timeout_amount" => 3,
        "timeout_unit" => "hours",
      }
      exec_ctx = build_exec_ctx(config, resume_token: "tok-abc")

      result = described_class.new(parameters: config).execute(exec_ctx)

      expect(result.first).to eq(exec_ctx.input_items)
    end

    it "raises on a non-positive wait amount" do
      config = { "resume" => "time_interval", "wait_amount" => 0, "wait_unit" => "hours" }
      exec_ctx = build_exec_ctx(config)

      expect { described_class.new(parameters: config).execute(exec_ctx) }.to raise_error(
        DiscourseWorkflows::NodeError,
        /Wait amount/,
      )
    end

    it "raises on an invalid wait unit" do
      config = { "resume" => "time_interval", "wait_amount" => 1, "wait_unit" => "weeks" }
      exec_ctx = build_exec_ctx(config)

      expect { described_class.new(parameters: config).execute(exec_ctx) }.to raise_error(
        DiscourseWorkflows::NodeError,
        /Invalid wait unit/,
      )
    end
  end
end

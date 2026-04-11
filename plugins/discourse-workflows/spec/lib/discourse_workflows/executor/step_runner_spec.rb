# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::StepRunner do
  subject(:step_runner) { described_class.new(state) }

  let(:state) do
    instance_double(
      DiscourseWorkflows::Executor::ExecutionState,
      resolver_context: {
      },
      user: nil,
      shared_sandbox: nil,
      next_step_position: 1,
    )
  end
  let(:node) do
    Struct.new(:id, :name, :type, :configuration).new("node-1", "Test", "action:test", {})
  end
  let(:node_type_class) do
    Class.new(DiscourseWorkflows::NodeType) do
      def self.identifier
        "action:test"
      end

      def self.configuration_schema
        {}
      end
    end
  end

  before { allow(state).to receive(:record_step) }

  describe "#run" do
    it "returns an error outcome when the step log contains errors" do
      exec_ctx =
        DiscourseWorkflows::NodeExecutionContext.new(
          input_items: [{ "json" => {} }],
          configuration: {
          },
          configuration_schema: node_type_class.configuration_schema,
          node_context: {
          },
          resolver: DiscourseWorkflows::ExpressionResolver.new({ "$json" => {} }),
        )
      exec_ctx.log.error("Step failed")

      outcome =
        step_runner.run(node, [{ "json" => {} }], node_type_class) do
          [[[{ "json" => { "ok" => true } }]], exec_ctx]
        end

      expect(outcome).to be_error
      expect(outcome.error).to be_a(StandardError)
      expect(outcome.error.message).to eq("Step failed")
      expect(outcome.step).to have_attributes(status: "error", error: "Step failed")
      expect(outcome.step.metadata["logs"]).to be_present
    end
  end
end

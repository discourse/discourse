# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::StepRunner do
  subject(:step_runner) do
    described_class.new(context: context, journal: journal, runtime: runtime, user: nil)
  end

  let(:context) do
    instance_double(DiscourseWorkflows::Executor::ExecutionContext, resolver_context: {})
  end
  let(:journal) do
    instance_double(DiscourseWorkflows::Executor::StepsJournal, next_step_position: 1)
  end
  let(:runtime) do
    instance_double(DiscourseWorkflows::Executor::ExecutionRuntime, shared_sandbox: nil)
  end
  let(:node) do
    Struct.new(:id, :name, :type, :configuration).new("node-1", "Test", "action:test", {})
  end
  let(:node_type_class) do
    Class.new(DiscourseWorkflows::NodeType) do
      def self.identifier
        "action:test"
      end

      def self.property_schema
        {}
      end
    end
  end

  before { allow(journal).to receive(:record_step) }

  describe "#run" do
    it "normalizes valid node output into a node result" do
      exec_ctx =
        DiscourseWorkflows::NodeExecutionContext.new(
          input_items: [{ "json" => {} }],
          configuration: {
          },
          property_schema: node_type_class.property_schema,
          node_context: {
          },
          resolver: DiscourseWorkflows::ExpressionResolver.new({ "$json" => {} }),
        )

      outcome =
        step_runner.run(node, [{ "json" => {} }], node_type_class) do
          [[[{ "json" => { "ok" => true } }]], exec_ctx]
        end

      expect(outcome).to be_success
      expect(outcome.result).to be_a(DiscourseWorkflows::NodeResult)
      expect(outcome.result.outputs).to eq("main" => [{ "json" => { "ok" => true } }])
      expect(outcome.step).to have_attributes(
        status: "success",
        output: [{ "json" => { "ok" => true } }],
      )
    end

    it "fails the step when a node returns an invalid output shape" do
      exec_ctx =
        DiscourseWorkflows::NodeExecutionContext.new(
          input_items: [{ "json" => {} }],
          configuration: {
          },
          property_schema: node_type_class.property_schema,
          node_context: {
          },
          resolver: DiscourseWorkflows::ExpressionResolver.new({ "$json" => {} }),
        )

      outcome =
        step_runner.run(node, [{ "json" => {} }], node_type_class) do
          [[{ "json" => { "ok" => true } }], exec_ctx]
        end

      expect(outcome).to be_error
      expect(outcome.error).to be_a(DiscourseWorkflows::ItemContract::Error)
      expect(outcome.step).to have_attributes(
        status: "error",
        error: "action:test: execute must return Array<Array<Item>>, got Array",
      )
    end

    it "returns an error outcome when the step log contains errors" do
      exec_ctx =
        DiscourseWorkflows::NodeExecutionContext.new(
          input_items: [{ "json" => {} }],
          configuration: {
          },
          property_schema: node_type_class.property_schema,
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

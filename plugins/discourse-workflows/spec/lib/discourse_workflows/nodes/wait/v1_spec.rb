# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Wait::V1 do
  subject(:result) { described_class.new(parameters: configuration).execute(execution_context) }

  let(:sandbox) { DiscourseWorkflows::JsSandbox.new({ "$json" => {} }) }
  let(:resume_token) { nil }
  let(:execution_context) do
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

  after { sandbox.dispose }

  describe ".capabilities" do
    it "marks the node as not producing data" do
      expect(described_class.capabilities).to include(produces_data: false)
    end
  end

  describe "#execute" do
    context "with interval mode" do
      let(:configuration) do
        { "resume" => "time_interval", "wait_amount" => 2, "wait_unit" => "hours" }
      end

      it "returns input items" do
        expect(result.first).to eq(execution_context.input_items)
      end
    end

    context "with webhook mode" do
      let(:configuration) { { "resume" => "webhook" } }
      let(:resume_token) { "tok-abc" }

      it "returns input items" do
        expect(result.first).to eq(execution_context.input_items)
      end
    end

    context "with a bounded webhook wait" do
      let(:configuration) do
        {
          "resume" => "webhook",
          "limit_wait_time" => true,
          "timeout_amount" => 3,
          "timeout_unit" => "hours",
        }
      end
      let(:resume_token) { "tok-abc" }

      it "returns input items" do
        expect(result.first).to eq(execution_context.input_items)
      end
    end

    context "with a non-positive wait amount" do
      let(:configuration) do
        { "resume" => "time_interval", "wait_amount" => 0, "wait_unit" => "hours" }
      end

      it "raises a node error" do
        expect { result }.to raise_error(DiscourseWorkflows::NodeError, /Wait amount/)
      end
    end

    context "with an invalid wait unit" do
      let(:configuration) do
        { "resume" => "time_interval", "wait_amount" => 1, "wait_unit" => "weeks" }
      end

      it "raises a node error" do
        expect { result }.to raise_error(DiscourseWorkflows::NodeError, /Invalid wait unit/)
      end
    end
  end
end

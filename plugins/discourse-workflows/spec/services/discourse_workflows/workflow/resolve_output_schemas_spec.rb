# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::ResolveOutputSchemas do
  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)

    let(:node) do
      { "id" => "manual", "type" => "trigger:manual", "typeVersion" => "1.0", "name" => "Manual" }
    end
    let(:params) { { nodes: [node], connections: {} } }
    let(:dependencies) { { guardian: admin.guardian } }

    context "when nodes are not hashes" do
      let(:params) { { nodes: ["x"], connections: {} } }

      it { is_expected.to fail_a_contract }
    end

    context "when nodes is not an array" do
      let(:params) { { nodes: "x", connections: {} } }

      it { is_expected.to fail_a_contract }
    end

    context "when connections is not a hash" do
      let(:params) { { nodes: [node], connections: [] } }

      it { is_expected.to fail_a_contract }
    end

    context "when there are too many nodes" do
      let(:params) do
        { nodes: Array.new(DiscourseWorkflows::WorkflowGraphValidator::MAX_NODES + 1) { node } }
      end

      it { is_expected.to fail_a_contract }
    end

    context "when user cannot manage workflows" do
      fab!(:user)

      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when everything is valid" do
      it "resolves the output schemas per node" do
        expect(result).to run_successfully
        expect(result[:output_schemas]).to have_key("manual")
      end
    end
  end
end

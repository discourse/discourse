# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::Update do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:workflow_id) }
    it { is_expected.to validate_presence_of(:name) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, guardian: user.guardian) }

    fab!(:user, :admin)
    fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: user) }

    let(:params) { { workflow_id: workflow.id, name:, enabled:, nodes:, connections: } }
    let(:name) { "Updated Workflow" }
    let(:enabled) { true }
    let(:nodes) { [] }
    let(:connections) { [] }

    before { SiteSetting.discourse_workflows_enabled = true }

    context "when contract is invalid" do
      let(:name) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when workflow is not found" do
      let(:params) { { workflow_id: -1, name: "Updated Workflow" } }

      it { is_expected.to fail_to_find_a_model(:workflow) }
    end

    context "when everything's ok" do
      let(:nodes) do
        [
          {
            client_id: "node_1",
            type: "trigger:topic_created",
            name: "Topic Created",
            configuration: {
              category_id: 1,
            },
          },
          {
            client_id: "node_2",
            type: "action:append_tags",
            name: "Append Tags",
            configuration: {
              tag_names: "test",
            },
          },
        ]
      end
      let(:connections) do
        [{ source_client_id: "node_1", target_client_id: "node_2", source_output: "yes" }]
      end

      it { is_expected.to run_successfully }

      it "updates the workflow attributes" do
        result
        workflow.reload
        expect(workflow).to have_attributes(name: "Updated Workflow", enabled: true)
      end

      it "populates the workflow graph" do
        result
        workflow.reload
        expect(workflow.nodes.count).to eq(2)
        expect(workflow.connections.count).to eq(1)
      end
    end
  end
end

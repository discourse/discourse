# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::Create do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user)

    let(:params) { { name:, nodes:, connections: } }
    let(:dependencies) { { guardian: user.guardian } }
    let(:name) { "My Workflow" }
    let(:nodes) { [] }
    let(:connections) { [] }

    before { SiteSetting.discourse_workflows_enabled = true }

    context "when contract is invalid" do
      let(:name) { nil }

      it { is_expected.to fail_a_contract }
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

      it "creates a workflow with correct attributes" do
        result
        workflow = DiscourseWorkflows::Workflow.last
        expect(workflow).to have_attributes(name: "My Workflow", created_by: user, enabled: false)
      end

      it "populates the workflow graph" do
        result
        workflow = DiscourseWorkflows::Workflow.last
        expect(workflow.nodes.count).to eq(2)
        expect(workflow.connections.count).to eq(1)
      end

      it "logs a staff action" do
        result
        log = UserHistory.last
        expect(log.custom_type).to eq("discourse_workflows_workflow_created")
        expect(log.subject).to eq("My Workflow")
      end
    end
  end
end

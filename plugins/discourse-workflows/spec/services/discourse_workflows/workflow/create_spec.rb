# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::Create do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user, :admin)

    let(:params) { { name:, nodes:, connections: } }
    let(:dependencies) { { guardian: user.guardian } }
    let(:name) { "My Workflow" }
    let(:nodes) { [] }
    let(:connections) { [] }

    context "when contract is invalid" do
      let(:name) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when user cannot create workflow" do
      fab!(:user)

      it { is_expected.to fail_a_policy(:can_create_workflow) }
    end

    context "when graph population fails" do
      before { DiscourseWorkflows::Workflow::Action::PopulateGraph.stubs(:call).returns(false) }

      it { is_expected.to fail_a_step(:populate_graph) }
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
            type: "action:topic_tags",
            name: "Topic Tags",
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
        expect(result[:workflow]).to have_attributes(
          name: "My Workflow",
          created_by: user,
          enabled: false,
        )
      end

      it "populates the workflow graph" do
        result
        workflow = result[:workflow].reload
        expect(workflow.parsed_nodes.size).to eq(2)
        expect(workflow.parsed_connections.size).to eq(1)
      end

      it "logs a staff action" do
        result
        log = UserHistory.last
        expect(log.custom_type).to eq("discourse_workflows_workflow_created")
        expect(log.subject).to eq("My Workflow")
      end

      it "clears the site cache" do
        Site.expects(:clear_cache).once
        result
      end
    end
  end
end

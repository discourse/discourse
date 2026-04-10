# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::Update do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:workflow_id) }
    it { is_expected.to validate_presence_of(:name) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user, :admin)
    fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: user) }

    let(:params) { { workflow_id: workflow.id, name:, enabled:, nodes:, connections: } }
    let(:dependencies) { { guardian: user.guardian } }
    let(:name) { "Updated Workflow" }
    let(:enabled) { true }
    let(:nodes) { [] }
    let(:connections) { [] }

    context "when contract is invalid" do
      let(:name) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when workflow is not found" do
      let(:params) { { workflow_id: -1, name: "Updated Workflow" } }

      it { is_expected.to fail_to_find_a_model(:workflow) }
    end

    context "when graph population fails" do
      let(:nodes) { [{ client_id: "node_1", type: "trigger:manual", name: "Manual" }] }

      before { DiscourseWorkflows::Workflow::Action::PopulateGraph.stubs(:call).returns(false) }

      it { is_expected.to fail_a_step(:populate_graph) }
    end

    context "when no graph data is provided" do
      let(:nodes) { nil }
      let(:connections) { nil }

      before do
        extra = build_workflow_graph { |g| g.node "existing-1", "trigger:manual", name: "Existing" }
        workflow.update!(nodes: extra[:nodes])
      end

      it { is_expected.to run_successfully }

      it "preserves existing nodes" do
        result
        expect(workflow.reload.parsed_nodes.size).to eq(1)
      end
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

      it "updates the workflow attributes" do
        result
        workflow.reload
        expect(workflow).to have_attributes(name: "Updated Workflow", enabled: true)
      end

      it "populates the workflow graph" do
        result
        workflow.reload
        expect(workflow.parsed_nodes.size).to eq(2)
        expect(workflow.parsed_connections.size).to eq(1)
      end

      it "clears the site cache" do
        Site.expects(:clear_cache).once
        result
      end

      context "when workflow is enabled with seconds schedule triggers" do
        let(:nodes) do
          [
            {
              client_id: "node_1",
              type: "trigger:schedule",
              name: "Schedule",
              configuration: {
                rules: [{ interval: "seconds", seconds_between_triggers: 10 }],
              },
            },
          ]
        end
        let(:connections) { [] }

        it "starts seconds schedule chains" do
          DiscourseWorkflows::ScheduleRule.expects(:start_seconds_chain!).once
          result
        end
      end

      context "when workflow is not enabled" do
        let(:enabled) { false }

        it "does not start seconds schedule chains" do
          DiscourseWorkflows::ScheduleRule.expects(:start_seconds_chain!).never
          result
        end
      end
    end
  end
end

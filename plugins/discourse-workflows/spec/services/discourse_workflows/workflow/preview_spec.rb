# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::Preview do
  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:workflow) do
      graph =
        build_workflow_graph do |builder|
          builder.node "trigger-1", "trigger:manual", name: "Run manually"
          builder.node "trigger-2", "trigger:topic_created", name: "Topic created"
        end
      Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)
    end

    let(:params) { { workflow_id: workflow.id, trigger_node_id: "trigger-1" } }
    let(:dependencies) { { guardian: admin.guardian } }

    before { SiteSetting.discourse_workflows_tests_enabled = true }

    context "when the feature is disabled" do
      before { SiteSetting.discourse_workflows_tests_enabled = false }

      it { is_expected.to fail_a_policy(:workflow_tests_enabled) }
    end

    context "when the trigger node does not exist" do
      let(:params) { super().merge(trigger_node_id: "nope") }

      it { is_expected.to fail_to_find_a_model(:trigger_node) }
    end

    context "when the trigger has no sample input" do
      let(:params) { super().merge(trigger_node_id: "trigger-2") }

      it { is_expected.to fail_to_find_a_model(:trigger_payload) }
    end

    it "creates a pending simulation with no test and enqueues it" do
      expect { expect(result).to run_successfully }.to change {
        Jobs::DiscourseWorkflows::RunSimulation.jobs.size
      }.by(1)

      expect(result[:execution]).to have_attributes(
        status: "pending",
        execution_mode: "simulation",
        workflow_test_id: nil,
        trigger_node_id: "trigger-1",
        trigger_data: {
        },
      )
    end
  end
end

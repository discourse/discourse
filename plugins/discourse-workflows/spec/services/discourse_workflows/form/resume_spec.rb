# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Form::Resume do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:execution_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, guardian:) }

    fab!(:user)
    let(:guardian) { Guardian.new(user) }

    fab!(:workflow) { Fabricate(:discourse_workflows_workflow, enabled: true) }
    fab!(:trigger_node) do
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "trigger:form",
        name: "Form Trigger",
        position_index: 0,
        configuration: {
          "uuid" => "a1b2c3d4-e5f6-7890-abcd-ef0123456789",
          "form_title" => "Trigger Form",
          "form_fields" => [
            { "field_label" => "Name", "field_type" => "text", "required" => true },
          ],
          "response_mode" => "on_received",
        },
      )
    end
    fab!(:form_action_node) do
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "action:form",
        name: "Form Action",
        position_index: 1,
        configuration: {
          "form_title" => "Resume Form",
          "form_fields" => [
            { "field_label" => "Feedback", "field_type" => "text", "required" => false },
          ],
        },
      )
    end
    fab!(:connection) do
      Fabricate(
        :discourse_workflows_connection,
        workflow: workflow,
        source_node: trigger_node,
        target_node: form_action_node,
      )
    end
    fab!(:execution) do
      Fabricate(
        :discourse_workflows_execution,
        workflow: workflow,
        status: :waiting,
        waiting_node_id: form_action_node.id,
        waiting_config: {
          "wait_type" => "form",
          "form_title" => "Resume Form",
          "form_fields" => [
            { "field_label" => "Feedback", "field_type" => "text", "required" => false },
          ],
        },
        context: {
          "Form Trigger" => [
            {
              "json" => {
                "form_data" => {
                  "name" => "Initial User",
                },
                "submitted_at" => "2026-01-01T00:00:00Z",
              },
            },
          ],
        },
        trigger_data: {
          "form_data" => {
            "name" => "Initial User",
          },
          "submitted_at" => "2026-01-01T00:00:00Z",
        },
        trigger_node_id: trigger_node.id,
        workflow_data: {
        },
      )
    end

    let(:execution_id) { execution.id }
    let(:form_data) { { "feedback" => "Looks good" } }
    let(:params) { { execution_id: execution_id, form_data: form_data } }

    before do
      SiteSetting.discourse_workflows_enabled = true
      DiscourseWorkflows::Registry.reset!
      DiscourseWorkflows::Registry.register_trigger(DiscourseWorkflows::Triggers::Form::V1)
      DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::Form::V1)
    end

    after { DiscourseWorkflows::Registry.reset! }

    context "when contract is invalid" do
      let(:execution_id) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when execution is not found" do
      let(:execution_id) { -1 }

      it { is_expected.to fail_to_find_a_model(:execution) }
    end

    context "when execution is not waiting" do
      before { execution.update!(status: :success) }

      it { is_expected.to fail_to_find_a_model(:execution) }
    end

    context "when execution wait_type is not form" do
      before { execution.update!(waiting_config: { "wait_type" => "approval" }) }

      it { is_expected.to fail_to_find_a_model(:execution) }
    end

    context "when waiting node is not found" do
      before { execution.update!(waiting_node_id: -1) }

      it { is_expected.to fail_to_find_a_model(:waiting_node) }
    end

    context "when everything is valid" do
      before do
        execution.update!(workflow_data: DiscourseWorkflows::WorkflowSnapshot.snapshot(workflow))
      end

      it { is_expected.to run_successfully }

      it "resumes the execution" do
        result
        expect(execution.reload.status).not_to eq("waiting")
      end
    end
  end
end

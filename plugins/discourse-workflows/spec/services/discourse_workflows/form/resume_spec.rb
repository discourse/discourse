# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Form::Resume do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:resume_token) }

    it "requires form_data to be a hash" do
      contract = described_class.new(resume_token: "token", form_data: "not_a_hash")
      expect(contract).not_to be_valid
      expect(contract.errors[:form_data]).to include("is invalid")
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user)
    let(:dependencies) { { guardian: Guardian.new(user) } }

    fab!(:workflow) do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1",
                 "trigger:form",
                 name: "Form Trigger",
                 configuration: {
                   "uuid" => "a1b2c3d4-e5f6-7890-abcd-ef0123456789",
                   "form_title" => "Trigger Form",
                   "form_fields" => [
                     { "field_label" => "Name", "field_type" => "text", "required" => true },
                   ],
                   "response_mode" => "on_received",
                 }
          g.node "form-action-1",
                 "action:form",
                 name: "Form Action",
                 configuration: {
                   "form_title" => "Resume Form",
                   "form_fields" => [
                     { "field_label" => "Feedback", "field_type" => "text", "required" => false },
                   ],
                 }
          g.chain "trigger-1", "form-action-1"
        end
      Fabricate(:discourse_workflows_workflow, enabled: true, **graph)
    end

    let(:resume_token) { SecureRandom.uuid }

    fab!(:execution) do
      Fabricate(
        :discourse_workflows_execution,
        workflow: workflow,
        status: :waiting,
        waiting_node_id: "form-action-1",
        waiting_config: {
          "wait_type" => "form",
          "resume_token" => "placeholder",
          "form_title" => "Resume Form",
          "form_fields" => [
            { "field_label" => "Feedback", "field_type" => "text", "required" => false },
          ],
        },
        trigger_data: {
          "form_data" => {
            "name" => "Initial User",
          },
          "submitted_at" => "2026-01-01T00:00:00Z",
        },
        trigger_node_id: "trigger-1",
      )
    end

    let(:form_data) { { "feedback" => "Looks good" } }
    let(:params) { { resume_token: resume_token, form_data: form_data } }

    before do
      execution.update!(
        waiting_config: execution.waiting_config.merge("resume_token" => resume_token),
      )
      DiscourseWorkflows::ExecutionData.create!(
        execution_id: execution.id,
        data: {
          "entries" => {
            "Form Trigger" => [
              {
                "node_id" => "trigger-1",
                "node_name" => "Form Trigger",
                "node_type" => "trigger:form",
                "position" => 0,
                "status" => "success",
                "output" => [{ "json" => { "form_data" => { "name" => "Initial User" } } }],
              },
            ],
          },
          "context" => {
            "trigger" => {
              "form_data" => {
                "name" => "Initial User",
              },
            },
            "Form Trigger" => [{ "json" => { "form_data" => { "name" => "Initial User" } } }],
            "__resume_token" => resume_token,
          },
        }.to_json,
        workflow_data: DiscourseWorkflows::WorkflowSnapshot.snapshot(workflow),
      )
    end

    context "when workflows are disabled" do
      before { SiteSetting.discourse_workflows_enabled = false }

      it { is_expected.to fail_a_policy(:workflows_enabled) }
    end

    context "when contract is invalid" do
      let(:params) { { resume_token: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when resume token does not match any waiting execution" do
      let(:resume_token) { SecureRandom.uuid }

      before do
        execution.update!(
          waiting_config: execution.waiting_config.merge("resume_token" => "different-token"),
        )
      end

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
      before { execution.update!(waiting_node_id: "nonexistent") }

      it { is_expected.to fail_to_find_a_model(:waiting_node) }
    end

    context "when required form fields are missing" do
      before do
        waiting_config = execution.waiting_config.dup
        waiting_config["form_fields"] = [
          { "field_label" => "Feedback", "field_type" => "text", "required" => true },
        ]
        execution.update!(waiting_config: waiting_config)

        node = workflow.nodes.find { |n| n["id"] == "form-action-1" }
        node["configuration"]["form_fields"] = [
          { "field_label" => "Feedback", "field_type" => "text", "required" => true },
        ]
        workflow.save!
        execution.execution_data.update!(
          workflow_data: DiscourseWorkflows::WorkflowSnapshot.snapshot(workflow),
        )
      end

      let(:form_data) { {} }

      it { is_expected.to fail_a_step(:validate_required_form_fields) }

      it "sets missing field labels" do
        expect(result[:missing_fields]).to eq(["Feedback"])
      end
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "resumes the execution" do
        result
        expect(execution.reload.status).not_to eq("waiting")
      end
    end
  end
end

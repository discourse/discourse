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
          g.node "trigger-1", "trigger:manual"
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

    let(:execution) do
      allow(MessageBus).to receive(:publish)
      exec = DiscourseWorkflows::Executor.new(workflow, "trigger-1", {}).run
      exec.update!(resume_token: resume_token)
      exec
    end

    let(:form_data) { { "feedback" => "Looks good" } }
    let(:params) { { resume_token: resume_token, form_data: form_data } }

    before { execution }

    context "when workflows are disabled" do
      before { SiteSetting.discourse_workflows_enabled = false }

      it { is_expected.to fail_a_policy(:workflows_enabled) }
    end

    context "when contract is invalid" do
      let(:params) { { resume_token: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when resume token does not match any waiting execution" do
      before { execution.update!(resume_token: "different-token") }

      it { is_expected.to fail_to_find_a_model(:execution) }
    end

    context "when execution is not waiting" do
      before { execution.update!(status: :success) }

      it { is_expected.to fail_to_find_a_model(:execution) }
    end

    context "when the waiting node is not a form action" do
      fab!(:workflow) do
        graph =
          build_workflow_graph do |g|
            g.node "trigger-1", "trigger:manual"
            g.node "wait-1",
                   "flow:wait",
                   configuration: {
                     "resume" => "webhook",
                     "webhook_suffix" => "resume",
                   }
            g.chain "trigger-1", "wait-1"
          end
        Fabricate(:discourse_workflows_workflow, enabled: true, **graph)
      end

      it { is_expected.to fail_to_find_a_model(:execution) }
    end

    context "when waiting node id no longer resolves in the workflow" do
      before { execution.update!(waiting_node_id: "nonexistent") }

      it { is_expected.to fail_to_find_a_model(:execution) }
    end

    context "when required form fields are missing" do
      fab!(:workflow) do
        graph =
          build_workflow_graph do |g|
            g.node "trigger-1", "trigger:manual"
            g.node "form-action-1",
                   "action:form",
                   name: "Form Action",
                   configuration: {
                     "form_title" => "Resume Form",
                     "form_fields" => [
                       { "field_label" => "Feedback", "field_type" => "text", "required" => true },
                     ],
                   }
            g.chain "trigger-1", "form-action-1"
          end
        Fabricate(:discourse_workflows_workflow, enabled: true, **graph)
      end

      let(:form_data) { {} }

      it { is_expected.to fail_a_step(:validate_form_submission) }

      it "sets the missing field error" do
        expect(result[:form_errors]).to contain_exactly({ field_label: "Feedback", code: :missing })
      end
    end

    context "when a number field receives a non-numeric value" do
      fab!(:workflow) do
        graph =
          build_workflow_graph do |g|
            g.node "trigger-1", "trigger:manual"
            g.node "form-action-1",
                   "action:form",
                   name: "Form Action",
                   configuration: {
                     "form_title" => "Resume Form",
                     "form_fields" => [
                       { "field_label" => "Age", "field_type" => "number", "required" => true },
                     ],
                   }
            g.chain "trigger-1", "form-action-1"
          end
        Fabricate(:discourse_workflows_workflow, enabled: true, **graph)
      end

      let(:form_data) { { "age" => "abc" } }

      it { is_expected.to fail_a_step(:validate_form_submission) }

      it "does not raise and reports the invalid value" do
        expect { result }.not_to raise_error
        expect(result[:form_errors]).to contain_exactly(
          { field_label: "Age", code: :invalid_value },
        )
      end
    end

    context "when the execution has already been claimed for resume" do
      before { allow(DiscourseWorkflows::Execution).to receive(:claim_for_resume).and_return(nil) }

      it { is_expected.to fail_to_find_a_model(:claimed_execution) }
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

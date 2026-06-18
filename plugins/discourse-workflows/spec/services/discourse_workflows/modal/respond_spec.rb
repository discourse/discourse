# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Modal::Respond do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:action_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user)

    let(:dependencies) { { guardian: user.guardian } }
    let(:params) { { action_id: action_id("approve") } }

    fab!(:workflow) do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:manual", name: "Manual"
          g.node "modal-1",
                 "action:modal",
                 name: "Modal",
                 configuration: {
                   "title" => "Approve topic?",
                   "body" => "Please choose",
                   "target_user" => user.username,
                   "buttons" => {
                     "values" => [
                       { "label" => "Approve", "value" => "approve", "style" => "primary" },
                       { "label" => "Reject", "value" => "reject", "style" => "danger" },
                     ],
                   },
                 }
          g.chain "trigger-1", "modal-1"
        end
      Fabricate(:discourse_workflows_workflow, name: "Published", published: true, **graph)
    end

    before { allow(MessageBus).to receive(:publish) }

    let!(:execution) do
      DiscourseWorkflows::Executor.new(
        workflow,
        "trigger-1",
        {},
        DiscourseWorkflows::Executor::ExecutionOptions.new(user: user),
      ).run
    end

    def action_id(action)
      DiscourseWorkflows::InteractiveResume.action_id(
        execution_id: execution.id,
        resume_token: execution.resume_token,
        action: action,
      )
    end

    it "pauses at the modal node before being resumed" do
      expect(execution.status).to eq("waiting")
    end

    context "when the action id is valid" do
      it { is_expected.to run_successfully }

      it "resumes the execution with the chosen button value" do
        result

        expect(execution.reload.status).to eq("success")
        output = execution.execution_data.entries.dig("modal-1", 0, "output", 0, "json")
        expect(output).to eq("button" => "approve")
      end
    end

    context "when the action id is blank" do
      let(:params) { { action_id: "" } }

      it { is_expected.to fail_a_contract }
    end

    context "when the action id is unknown" do
      let(:params) { { action_id: "999:approve:deadbeef" } }

      it { is_expected.to fail_to_find_a_model(:resume_request) }
    end

    context "when the action is not one of the configured buttons" do
      let(:params) { { action_id: action_id("delete") } }

      it { is_expected.to fail_to_find_a_model(:resume_request) }
    end

    context "when the execution was already resumed" do
      before { described_class.call(params:, **dependencies) }

      it "no longer finds a waiting execution to resume" do
        expect(execution.reload.status).to eq("success")
        is_expected.to fail_to_find_a_model(:resume_request)
      end
    end
  end
end

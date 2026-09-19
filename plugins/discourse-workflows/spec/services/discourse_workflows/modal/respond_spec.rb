# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Modal::Respond do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:action_id) }

    it do
      is_expected.to validate_length_of(:modal_id).is_at_most(
        DiscourseWorkflows::Nodes::Modal::V1::MODAL_ID_MAX_LENGTH,
      )
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user)

    let(:dependencies) { { guardian: user.guardian } }
    let(:action) { "approve" }
    let(:target_user_id) { user.id }
    let(:action_id) do
      DiscourseWorkflows::InteractiveResume.action_id(
        execution_id: execution.id,
        resume_token: execution.resume_token,
        action:,
        target_user_id:,
      )
    end
    let(:modal_id) { "abcd1234abcd1234" }
    let(:params) { { action_id:, modal_id: } }

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

    let!(:execution) do
      DiscourseWorkflows::Executor.new(
        workflow,
        "trigger-1",
        {},
        DiscourseWorkflows::Executor::ExecutionOptions.new(user: user),
      ).run
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

      it "tells the user's other tabs to close their copies of the modal" do
        messages =
          MessageBus.track_publish(DiscourseWorkflows::Nodes::Modal::V1.user_channel(user.id)) do
            result
          end
        close_messages = messages.select { |message| message.data[:type] == "close_modal" }

        expect(close_messages.size).to eq(1)
        expect(close_messages.first.user_ids).to eq([user.id])
        expect(close_messages.first.data[:modal_id]).to eq(modal_id)
      end
    end

    context "when no modal id is provided" do
      let(:modal_id) { nil }

      it { is_expected.to run_successfully }

      it "resumes the execution without broadcasting a close" do
        messages =
          MessageBus.track_publish(DiscourseWorkflows::Nodes::Modal::V1.user_channel(user.id)) do
            result
          end

        expect(messages).to be_empty
        expect(execution.reload.status).to eq("success")
      end
    end

    context "when another tab claims the resume first" do
      before { allow(DiscourseWorkflows::Execution).to receive(:claim_for_resume).and_return(nil) }

      it { is_expected.to run_successfully }

      it "leaves the execution alone but still closes the modal copies" do
        messages =
          MessageBus.track_publish(DiscourseWorkflows::Nodes::Modal::V1.user_channel(user.id)) do
            result
          end
        close_messages = messages.select { |message| message.data[:type] == "close_modal" }

        expect(close_messages.size).to eq(1)
        expect(execution.reload.status).to eq("waiting")
      end
    end

    context "when the action id is blank" do
      let(:params) { { action_id: "" } }

      it { is_expected.to fail_a_contract }
    end

    context "when the action id does not parse" do
      let(:params) { { action_id: "999:approve:deadbeef" } }

      it { is_expected.to fail_to_find_a_model(:payload) }
    end

    context "when the action is not one of the configured buttons" do
      let(:action) { "delete" }

      it { is_expected.to run_successfully }

      it "acknowledges the response but leaves the execution waiting" do
        messages =
          MessageBus.track_publish(DiscourseWorkflows::Nodes::Modal::V1.user_channel(user.id)) do
            result
          end

        expect(messages.map { |message| message.data[:type] }).to eq(["close_modal"])
        expect(execution.reload.status).to eq("waiting")
      end
    end

    context "when a user other than the modal target holds the token" do
      fab!(:other_user, :user)

      let(:dependencies) { { guardian: other_user.guardian } }

      it { is_expected.to fail_a_policy(:targets_current_user) }

      it "leaves the execution waiting instead of resuming it" do
        described_class.call(params:, **dependencies)

        expect(execution.reload.status).to eq("waiting")
      end
    end

    context "when the execution was already resumed" do
      before { described_class.call(params:, **dependencies) }

      it { is_expected.to run_successfully }

      it "closes the leftover copies without touching the finished execution" do
        messages =
          MessageBus.track_publish(DiscourseWorkflows::Nodes::Modal::V1.user_channel(user.id)) do
            result
          end

        expect(messages.map { |message| message.data[:type] }).to eq(["close_modal"])
        expect(execution.reload.status).to eq("success")
      end
    end
  end
end

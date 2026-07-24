# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::AiAuthoring::Start do
  before { SiteSetting.discourse_workflows_ai_authoring_enabled = true }

  describe described_class::Contract, type: :model do
    subject(:contract) do
      described_class.new(message: message, mode: mode, workflow_id: workflow_id)
    end

    let(:message) { "Create a manual workflow" }
    let(:mode) { "create" }
    let(:workflow_id) { nil }

    it { is_expected.to be_valid }

    context "when message is blank" do
      let(:message) { "  " }

      it "adds the authoring message error" do
        expect(contract).not_to be_valid
        expect(contract.errors.full_messages).to contain_exactly(
          I18n.t("discourse_workflows.ai.error_message_required"),
        )
      end
    end

    context "when message is too long" do
      let(:message) { "a" * (SiteSetting.discourse_workflows_ai_authoring_max_prompt_length + 1) }

      it "adds the prompt length error" do
        expect(contract).not_to be_valid
        expect(contract.errors.full_messages).to contain_exactly(
          I18n.t("discourse_workflows.ai.error_message_too_long"),
        )
      end
    end

    context "when mode is invalid" do
      let(:mode) { "rewrite" }

      it "adds the mode error" do
        expect(contract).not_to be_valid
        expect(contract.errors.full_messages).to contain_exactly(
          I18n.t("discourse_workflows.ai.error_invalid_mode"),
        )
      end
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user, :admin)

    let(:params) do
      { message: message, mode: mode, workflow_id: workflow_id, session_id: session_id }
    end
    let(:dependencies) { { guardian: user.guardian } }
    let(:message) { "Create a manual workflow that logs hello" }
    let(:mode) { "create" }
    let(:workflow_id) { nil }
    let(:session_id) { nil }

    context "when AI authoring is disabled" do
      before { SiteSetting.discourse_workflows_ai_authoring_enabled = false }

      it { is_expected.to fail_a_policy(:ai_authoring_enabled) }
    end

    context "when contract is invalid" do
      let(:message) { "" }

      it { is_expected.to fail_a_contract }
    end

    context "when user cannot manage workflows" do
      fab!(:user)

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when requested workflow does not exist" do
      let(:workflow_id) { -1 }

      it { is_expected.to fail_a_policy(:workflow_exists_when_requested) }
    end

    context "when requested session does not exist" do
      let(:session_id) { -1 }

      it { is_expected.to fail_to_find_a_model(:session) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "creates a session and enqueues authoring" do
        expect { result }.to change(DiscourseWorkflows::AiAuthoringSession, :count).by(1)

        session = result[:session]
        expect(session).to have_attributes(
          user_id: user.id,
          workflow_id: nil,
          status: "generating",
          latest_request: "Create a manual workflow that logs hello",
        )
        expect(Jobs::DiscourseWorkflows::AuthorWithAi.jobs.last["args"].first).to include(
          "session_id" => session.id,
          "user_id" => user.id,
          "generation_id" => result[:generation_id],
        )
      end
    end

    context "with a workflow" do
      fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: user) }

      let(:mode) { nil }
      let(:workflow_id) { workflow.id }

      it "stores the workflow base graph and defaults to edit mode" do
        result

        session = result[:session]
        expect(session).to have_attributes(
          workflow_id: workflow.id,
          base_workflow_version_id: workflow.version_id,
          base_graph_digest: DiscourseWorkflows::Ai::GraphDigest.call(workflow),
        )
        expect(session.messages.last["content"]).to eq(
          JSON.pretty_generate(
            {
              mode: "edit",
              message: "Create a manual workflow that logs hello",
              workflow_id: workflow.id,
            },
          ),
        )
      end
    end

    context "with an existing session" do
      fab!(:session) do
        Fabricate(:discourse_workflows_ai_authoring_session, user: user, status: "drafting")
      end

      let(:session_id) { session.id }
      let(:mode) { "debug" }

      it "appends the new request to the session" do
        expect { result }.not_to change(DiscourseWorkflows::AiAuthoringSession, :count)

        expect(session.reload).to have_attributes(
          status: "generating",
          latest_request: "Create a manual workflow that logs hello",
        )
        expect(session.messages.last["content"]).to eq(
          JSON.pretty_generate(
            { mode: "debug", message: "Create a manual workflow that logs hello" },
          ),
        )
      end
    end
  end
end

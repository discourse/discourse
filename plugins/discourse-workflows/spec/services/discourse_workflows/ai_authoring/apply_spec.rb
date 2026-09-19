# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::AiAuthoring::Apply do
  before { SiteSetting.discourse_workflows_ai_authoring_enabled = true }

  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:session_id) }
    it { is_expected.to validate_presence_of(:workflow_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user, :admin)
    fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: user) }

    let(:session) do
      Fabricate(
        :discourse_workflows_ai_authoring_session,
        user: user,
        workflow: workflow,
        status: status,
        proposed_patch: {
          "operations" => operations,
        },
        base_graph_digest: base_graph_digest,
        risk_level: "medium",
      )
    end

    let(:params) { { session_id: session.id, workflow_id: workflow.id } }
    let(:dependencies) { { guardian: user.guardian } }
    let(:status) { "proposal_ready" }
    let(:base_graph_digest) { DiscourseWorkflows::Ai::GraphDigest.call(workflow) }
    let(:operations) do
      [
        {
          op: "add_node",
          client_id: "manual-trigger",
          node: {
            type: "trigger:manual",
            name: "Manual trigger",
            position: {
              x: 0,
              y: 0,
            },
          },
        },
      ]
    end

    context "when AI authoring is disabled" do
      before { SiteSetting.discourse_workflows_ai_authoring_enabled = false }

      it { is_expected.to fail_a_policy(:ai_authoring_enabled) }
    end

    context "when contract is invalid" do
      let(:params) { { session_id: nil, workflow_id: workflow.id } }

      it { is_expected.to fail_a_contract }
    end

    context "when user cannot manage workflows" do
      fab!(:user)

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when session does not exist" do
      let(:params) { { session_id: -1, workflow_id: workflow.id } }

      it { is_expected.to fail_to_find_a_model(:session) }
    end

    context "when proposal is not ready" do
      let(:status) { "error" }

      it { is_expected.to fail_a_policy(:proposal_ready) }
    end

    context "without operations" do
      let(:operations) { [] }

      it { is_expected.to fail_to_find_a_model(:operations) }
    end

    context "when proposal is stale" do
      let(:base_graph_digest) { "stale" }

      it { is_expected.to fail_a_policy(:proposal_current) }
    end

    context "when patch is invalid" do
      let(:operations) { [{ op: "unknown" }] }

      it { is_expected.to fail_a_policy(:patch_valid) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "applies the patch and marks the session applied" do
        expect { result }.to change { workflow.reload.nodes.size }.from(0).to(1)

        expect(workflow.nodes.first["type"]).to eq("trigger:manual")
        expect(session.reload).to have_attributes(status: "applied")
        expect(session.applied_at).to be_present
      end
    end
  end
end

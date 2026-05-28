# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::DiscardDraft do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:workflow_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user, :admin)
    fab!(:workflow) do
      graph = build_workflow_graph { |builder| builder.node "published-1", "trigger:manual" }
      Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)
    end

    let(:params) { { workflow_id: workflow.id } }
    let(:dependencies) { { guardian: user.guardian } }

    before do
      graph = build_workflow_graph { |builder| builder.node "draft-1", "trigger:schedule" }
      workflow.update!(
        name: "Draft workflow",
        nodes: graph[:nodes],
        connections: graph[:connections],
        settings: {
          "timezone" => "Europe/Paris",
        },
      )
      workflow.snapshot!(user: user)
    end

    context "when the contract is invalid" do
      let(:params) { { workflow_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when workflow is not found" do
      let(:params) { { workflow_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:workflow) }
    end

    context "when the workflow has no active version" do
      fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: user) }

      it { is_expected.to fail_to_find_a_model(:active_version) }
    end

    context "when user cannot manage workflows" do
      fab!(:non_admin, :user)

      let(:dependencies) { { guardian: non_admin.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "restores the published workflow version" do
        published_version = workflow.active_version

        result

        expect(workflow.reload).to have_attributes(
          name: published_version.name,
          nodes: published_version.nodes,
          connections: published_version.connections,
          settings: published_version.settings,
          version_id: published_version.version_id,
          active_version_id: published_version.version_id,
        )
        expect(workflow).not_to have_unpublished_changes
      end

      it_behaves_like "expires workflow caches"
    end
  end
end

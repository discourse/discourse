# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::RevertToVersion do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:workflow_id) }
    it { is_expected.to validate_presence_of(:version_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user, :admin)
    fab!(:workflow) do
      graph = build_workflow_graph { |builder| builder.node "v1-1", "trigger:manual" }
      Fabricate(:discourse_workflows_workflow, created_by: user, **graph)
    end

    let!(:first_version) { workflow.workflow_versions.order(:version_number).first }

    let(:params) { { workflow_id: workflow.id, version_id: first_version.version_id } }
    let(:dependencies) { { guardian: user.guardian } }

    before do
      graph = build_workflow_graph { |builder| builder.node "v2-1", "trigger:schedule" }
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
      let(:params) { { workflow_id: workflow.id, version_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when the workflow is not found" do
      let(:params) { { workflow_id: -1, version_id: first_version.version_id } }

      it { is_expected.to fail_to_find_a_model(:workflow) }
    end

    context "when the version is not found" do
      let(:params) { { workflow_id: workflow.id, version_id: SecureRandom.uuid } }

      it { is_expected.to fail_to_find_a_model(:version) }
    end

    context "when the version belongs to another workflow" do
      fab!(:other_workflow) { Fabricate(:discourse_workflows_workflow, created_by: user) }

      let(:params) { { workflow_id: workflow.id, version_id: other_workflow.version_id } }

      it { is_expected.to fail_to_find_a_model(:version) }
    end

    context "when the user cannot manage workflows" do
      fab!(:non_admin, :user)

      let(:dependencies) { { guardian: non_admin.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "restores the chosen version into the draft" do
        result

        expect(workflow.reload).to have_attributes(
          name: first_version.name,
          nodes: first_version.nodes,
          connections: first_version.connections,
          settings: first_version.settings,
          version_id: first_version.version_id,
        )
      end

      it "does not create a new version" do
        expect { result }.not_to change { workflow.workflow_versions.count }
      end

      it_behaves_like "expires workflow caches"
    end
  end
end

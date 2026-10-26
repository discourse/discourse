# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::NodeType::Upgrade do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:nodes) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)

    let(:params) { { nodes: [node] } }
    let(:dependencies) { { guardian: admin.guardian } }
    let(:node) do
      {
        id: "node-id",
        type: "action:upgrade_service_test",
        typeVersion: "1.0",
        name: "Rename",
        parameters: {
          title: "New title",
        },
      }
    end

    before do
      register_versioned_workflow_nodes(
        "action:upgrade_service_test",
        v1_deprecation: {
          superseded_by: "2.0",
        },
      )
    end

    context "when contract is invalid" do
      let(:params) { { nodes: [] } }

      it { is_expected.to fail_a_contract }
    end

    context "when user cannot manage workflows" do
      fab!(:user)

      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when a node is malformed" do
      let(:node) { "not a node" }

      it { is_expected.to fail_to_find_a_model(:upgrade) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "upgrades the deprecated nodes" do
        expect(result.upgrade.nodes).to contain_exactly(
          include(
            "id" => "node-id",
            "name" => "Rename",
            "typeVersion" => "2.0",
            "parameters" => {
              "title" => "New title",
            },
          ),
        )
      end
    end
  end
end

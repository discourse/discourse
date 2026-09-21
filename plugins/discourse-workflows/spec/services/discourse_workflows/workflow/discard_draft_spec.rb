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

    context "when the published version references a removed node pack" do
      it "returns a service failure and preserves the draft" do
        pack = install_node_pack(user)
        pack_graph = build_workflow_graph { |builder| builder.node "choice-1", "action:jev.choice" }
        pack_workflow =
          Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **pack_graph)
        replacement_graph =
          build_workflow_graph { |builder| builder.node "manual-1", "trigger:manual" }
        pack_workflow.update!(**replacement_graph)
        pack.update!(removed_at: Time.current, enabled: false, palette_visible: false)
        pack.definitions.update_all(retired_at: Time.current)
        DiscourseWorkflows::NodePacks::Runtime.bump!

        failed =
          described_class.call(params: { workflow_id: pack_workflow.id }, guardian: user.guardian)

        expect(failed).to fail_a_step(:restore_published_version)
        expect(pack_workflow.reload.nodes).to eq(replacement_graph[:nodes])
      end
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

  def install_node_pack(user)
    manifest =
      File.read(Rails.root.join("plugins/discourse-workflows/docs/examples/node-packs/jev.json"))
    DiscourseWorkflows::NodePack::Install.call(
      params: {
        manifest:,
        approved_destinations: ["https://api.typesafe.ai"],
      },
      guardian: user.guardian,
    )[
      :node_pack
    ]
  end
end

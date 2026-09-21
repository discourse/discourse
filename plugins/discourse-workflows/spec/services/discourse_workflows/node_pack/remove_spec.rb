# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::NodePack::Remove do
  describe ".call" do
    subject(:result) do
      described_class.call(params: { node_pack_id: pack.id }, guardian: admin.guardian)
    end

    fab!(:admin)

    let(:manifest) do
      File.read(Rails.root.join("plugins/discourse-workflows/docs/examples/node-packs/jev.json"))
    end
    let!(:pack) do
      DiscourseWorkflows::NodePack::Install.call(
        params: {
          manifest:,
          approved_destinations: ["https://api.typesafe.ai"],
        },
        guardian: admin.guardian,
      )[
        :node_pack
      ]
    end
    let(:pack_node) do
      {
        "id" => "choice-1",
        "name" => "Choice",
        "type" => "action:jev.choice",
        "typeVersion" => "1.0",
        "parameters" => {
        },
      }
    end

    it "blocks removal when a current workflow references the pack" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, nodes: [pack_node])

      expect(result).to fail_a_policy(:not_in_use)
      expect(result[:referencing_workflows]).to contain_exactly(
        include(id: workflow.id, name: workflow.name, node_ids: ["choice-1"]),
      )
    end

    it "serializes graph writes before removal and revalidates after removal" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, nodes: [])
      removal = nil

      DiscourseWorkflows::NodePacks::LifecycleLock.with_graph_write([pack_node]) do
        workflow.update!(nodes: [pack_node])
        removal = described_class.call(params: { node_pack_id: pack.id }, guardian: admin.guardian)
      end

      expect(removal).to fail_a_policy(:not_in_use)
      expect(pack.reload.removed_at).to be_nil

      workflow.update!(nodes: [])
      removed = described_class.call(params: { node_pack_id: pack.id }, guardian: admin.guardian)
      expect(removed).to run_successfully
      expect do
        DiscourseWorkflows::NodePacks::LifecycleLock.with_graph_write([pack_node]) { nil }
      end.to raise_error(DiscourseWorkflows::NodePacks::LifecycleLock::MissingReferencesError)
    end

    it "blocks removal for a live execution's stored snapshot" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, nodes: [])
      execution = Fabricate(:discourse_workflows_execution, workflow:)
      Fabricate(
        :discourse_workflows_execution_data,
        execution:,
        workflow_data: {
          "nodes" => [pack_node],
          "connections" => {
          },
        },
      )

      expect(result).to fail_a_policy(:not_in_use)
      expect(result[:active_executions]).to eq(1)
    end

    it "blocks removal for pending execution references but ignores terminal history" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, nodes: [pack_node])
      old_version_id = workflow.version_id
      workflow.update!(nodes: [])
      workflow.snapshot!(user: admin)
      execution =
        Fabricate(:discourse_workflows_execution, workflow:, workflow_version_id: old_version_id)

      expect(result).to fail_a_policy(:not_in_use)
      expect(result[:active_executions]).to eq(1)

      execution.update!(status: :success)
      removed = described_class.call(params: { node_pack_id: pack.id }, guardian: admin.guardian)
      expect(removed).to run_successfully
      expect(pack.reload.removed_at).to be_present
      expect(pack.definitions.count).to eq(4)
    end
  end
end

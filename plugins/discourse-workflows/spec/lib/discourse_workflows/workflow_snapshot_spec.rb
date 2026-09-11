# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowSnapshot do
  describe "#pinned_items_for" do
    subject(:snapshot) { described_class.new(data) }

    let(:pinned_items) { [{ "json" => { "id" => 1 } }, { "json" => { "id" => 2 } }] }
    let(:pin_data) { { "Source" => pinned_items } }
    let(:data) do
      {
        "nodes" => [
          { "id" => "a", "name" => "Source", "type" => "trigger:manual", "typeVersion" => "1.0" },
          { "id" => "b", "name" => "Target", "type" => "action:sort", "typeVersion" => "1.0" },
        ],
        "connections" => {
          "Source" => {
            "main" => [[{ "node" => "Target", "type" => "main", "index" => 0 }]],
          },
        },
        "pinData" => pin_data,
      }
    end

    it "returns the pinned items of the connected upstream node" do
      expect(snapshot.pinned_items_for(snapshot.find_node("b"))).to eq(pinned_items)
    end

    context "when the upstream node has no pinned data" do
      let(:pin_data) { { "Elsewhere" => pinned_items } }

      it "returns an empty array" do
        expect(snapshot.pinned_items_for(snapshot.find_node("b"))).to eq([])
      end
    end

    context "when the node has no upstream connection" do
      it "returns an empty array" do
        expect(snapshot.pinned_items_for(snapshot.find_node("a"))).to eq([])
      end
    end

    context "when nothing is pinned at all" do
      let(:pin_data) { {} }

      it "returns an empty array" do
        expect(snapshot.pinned_items_for(snapshot.find_node("b"))).to eq([])
      end
    end
  end

  describe "#setting_schema" do
    it "defaults to an empty array when the source data has none" do
      expect(described_class.new({}).setting_schema).to eq([])
    end

    it "reads settingSchema from the source data" do
      schema = [{ "key" => "priority", "type" => "string", "value" => "urgent" }]

      expect(described_class.new("settingSchema" => schema).setting_schema).to eq(schema)
    end

    it "round-trips through #to_h" do
      schema = [{ "key" => "priority", "type" => "string", "value" => "urgent" }]
      snapshot = described_class.new("settingSchema" => schema)

      expect(described_class.new(snapshot.to_h).setting_schema).to eq(schema)
    end
  end

  describe ".from_workflow" do
    fab!(:workflow, :discourse_workflows_workflow)
    fab!(:setting_field) do
      Fabricate(:discourse_workflows_workflow_setting_field, workflow:, value: "urgent")
    end

    context "when published: false" do
      it "uses the workflow's live setting fields schema" do
        snapshot = described_class.from_workflow(workflow, published: false)

        expect(snapshot.setting_schema).to eq(workflow.reload.setting_fields_schema)
        expect(snapshot.setting_schema.first["value"]).to eq("urgent")
      end
    end

    context "when published: true" do
      before do
        version = workflow.snapshot!(user: workflow.created_by)
        workflow.update_columns(active_version_id: version.version_id)
      end

      it "uses the active version's setting schema" do
        snapshot = described_class.from_workflow(workflow.reload, published: true)

        expect(snapshot.setting_schema).to eq(workflow.active_version.setting_schema)
      end
    end
  end

  describe ".from_version" do
    fab!(:workflow, :discourse_workflows_workflow)
    fab!(:setting_field) do
      Fabricate(:discourse_workflows_workflow_setting_field, workflow:, value: "urgent")
    end

    it "uses the given version's setting schema" do
      version = workflow.snapshot!(user: workflow.created_by)

      snapshot = described_class.from_version(workflow, version)

      expect(snapshot.setting_schema).to eq(version.setting_schema)
      expect(snapshot.setting_schema.first["value"]).to eq("urgent")
    end
  end
end

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
end

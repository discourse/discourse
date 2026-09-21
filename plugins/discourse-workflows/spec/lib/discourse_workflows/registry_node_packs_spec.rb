# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Registry do
  fab!(:admin)

  let(:manifest) do
    File.read(Rails.root.join("plugins/discourse-workflows/docs/examples/node-packs/jev.json"))
  end

  before do
    DiscourseWorkflows::NodePack::Install.call(
      params: {
        manifest:,
        approved_destinations: ["https://api.typesafe.ai"],
      },
      guardian: admin.guardian,
    )
  end

  after { DiscourseWorkflows::NodePacks::Runtime.clear! }

  it "exposes imported metadata, schemas, examples, and literal labels" do
    node_class = described_class.find_node_type("action:jev.choice", version: "1.0")
    serialized =
      DiscourseWorkflows::NodeTypeSerializer
        .new(identifier: "action:jev.choice", available_versions: ["1.0"])
        .to_h
        .dig(:versions, "1.0")

    expect(node_class).to be < DiscourseWorkflows::NodePacks::DeclarativeNode
    expect(DiscourseWorkflows::NodeType.registered_nodes).not_to include(node_class)
    expect(serialized.dig(:ui, :label)).to eq("Choose an option")
    expect(serialized.dig(:ui, :palette_group, :label)).to eq("Jev")
    expect(serialized.dig(:ui, :pack, :key)).to eq("jev")
    expect(serialized.dig(:credentials, 0, :label)).to eq("TypeSafe API key")
    expect(serialized.dig(:properties, :state, :label)).to eq("State")
    expect(serialized[:examples]).not_to be_empty
  end

  it "retains disabled definitions for fail-closed lookup and removes soft-deleted packs" do
    pack = DiscourseWorkflows::NodePack.find_by!(key: "jev")
    pack.update!(enabled: false)
    DiscourseWorkflows::NodePacks::Runtime.bump!

    node_class = described_class.find_node_type("action:jev.choice", version: "1.0")
    expect(node_class).not_to be_available

    pack.update!(removed_at: Time.current)
    DiscourseWorkflows::NodePacks::Runtime.bump!
    expect(described_class.find_node_type("action:jev.choice", version: "1.0")).to be_nil
    expect(DiscourseWorkflows::NodePackDefinition.where(node_pack_id: pack.id).count).to eq(4)
  end
end

# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Registry do
  before { described_class.reset_indexes! }

  describe ".find_node_type" do
    it "finds a registered node type by identifier" do
      trigger = described_class.triggers.first
      expect(described_class.find_node_type(trigger.identifier)).to eq(trigger)
    end

    it "returns nil for unknown identifiers" do
      expect(described_class.find_node_type("trigger:nonexistent")).to be_nil
    end

    it "finds a registered node type by identifier and version" do
      v1 =
        Class.new(DiscourseWorkflows::NodeType) do
          description(name: "action:registry_versioned_test", version: "1.0")
        end
      v2 =
        Class.new(DiscourseWorkflows::NodeType) do
          description(name: "action:registry_versioned_test", version: "2.0")
        end

      DiscoursePluginRegistry.register_discourse_workflows_node(v1, Plugin::Instance.new)
      DiscoursePluginRegistry.register_discourse_workflows_node(v2, Plugin::Instance.new)
      described_class.reset_indexes!

      expect(
        described_class.find_node_type("action:registry_versioned_test", version: "1.0"),
      ).to eq(v1)
      expect(
        described_class.find_node_type("action:registry_versioned_test", version: "2.0"),
      ).to eq(v2)
      expect(described_class.available_versions("action:registry_versioned_test")).to eq(
        %w[1.0 2.0],
      )
      expect(described_class.latest_version("action:registry_versioned_test")).to eq("2.0")
    ensure
      DiscoursePluginRegistry._raw_discourse_workflows_nodes.reject! do |entry|
        [v1, v2].include?(entry[:value])
      end
      described_class.reset_indexes!
    end

    it "rejects duplicate node identifier and version registrations" do
      first =
        Class.new(DiscourseWorkflows::NodeType) do
          description(name: "action:registry_duplicate_test", version: "1.0")
        end
      duplicate =
        Class.new(DiscourseWorkflows::NodeType) do
          description(name: "action:registry_duplicate_test", version: "1.0")
        end

      DiscoursePluginRegistry.register_discourse_workflows_node(first, Plugin::Instance.new)
      DiscoursePluginRegistry.register_discourse_workflows_node(duplicate, Plugin::Instance.new)
      described_class.reset_indexes!

      expect { described_class.find_node_type("action:registry_duplicate_test") }.to raise_error(
        ArgumentError,
        "Duplicate workflow node type action:registry_duplicate_test v1.0",
      )
    ensure
      DiscoursePluginRegistry._raw_discourse_workflows_nodes.reject! do |entry|
        [first, duplicate].include?(entry[:value])
      end
      described_class.reset_indexes!
    end
  end
end

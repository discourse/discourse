# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::AiAgent do
  fab!(:enabled_agent) { Fabricate(:ai_agent, enabled: true, name: "Helper Bot") }

  describe ".configuration_schema" do
    it "uses select control for agent selection" do
      schema = described_class.configuration_schema[:agent_id]
      expect(schema[:ui]).to eq(control: :select)
      expect(schema[:type]).to eq(:integer)
      expect(schema[:required]).to eq(true)
      expect(schema[:options]).to include(value: enabled_agent.id, label: "Helper Bot")
    end
  end

  describe ".property_i18n_prefix" do
    it "uses the discourse-ai workflow translations for field labels" do
      expect(described_class.property_i18n_prefix).to eq("discourse_ai.discourse_workflows")
    end
  end

  describe ".palette_group" do
    it "defines its palette group metadata locally" do
      expect(described_class.palette_group).to eq(
        id: "ai",
        icon: "robot",
        label_key: "discourse_workflows.add_node.categories.ai",
        order: 40,
      )
    end
  end

  describe ".metadata" do
    it "provides enabled agents for the configurator" do
      expect(described_class.metadata[:agents]).to include(id: enabled_agent.id, name: "Helper Bot")
    end
  end
end

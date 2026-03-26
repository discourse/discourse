# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Actions::AiAgent do
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

  describe ".metadata" do
    it "provides a plugin translation root and enabled agents" do
      expect(described_class.metadata[:i18n_prefix]).to eq("discourse_ai.discourse_workflows")
      expect(described_class.metadata[:agents]).to include(id: enabled_agent.id, name: "Helper Bot")
    end
  end
end

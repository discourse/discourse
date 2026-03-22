# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Actions::AiAgent do
  fab!(:enabled_agent) { Fabricate(:ai_agent, enabled: true, name: "Helper Bot") }

  describe ".configuration_schema" do
    it "uses combo box ui hints for agent selection" do
      expect(described_class.configuration_schema.dig(:agent_id, :ui)).to eq(
        control: :combo_box,
        expression: false,
        filterable: true,
        name_property: :name,
        none: "discourse_ai.discourse_workflows.ai_agent.select_agent",
        options_source: :agents,
        patch_from_option: {
          agent_name: :name,
        },
        value_property: :id,
      )
    end
  end

  describe ".metadata" do
    it "provides a plugin translation root and enabled agents" do
      expect(described_class.metadata[:i18n_prefix]).to eq("discourse_ai.discourse_workflows")
      expect(described_class.metadata[:agents]).to include(id: enabled_agent.id, name: "Helper Bot")
    end
  end
end

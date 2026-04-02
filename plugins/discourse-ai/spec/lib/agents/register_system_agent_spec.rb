# frozen_string_literal: true

describe DiscourseAi::Agents::Agent do
  let(:expected_agent_id) do
    -(Zlib.crc32("data_explorer_query_generation") % 1_000_000 + 1_000_000)
  end

  describe ".external_tool_by_name" do
    it "finds external tools from the raw plugin registry" do
      expect(described_class.external_tool_by_name("ValidateSql")).to eq(
        DiscourseDataExplorer::Tools::ValidateSql,
      )
      expect(described_class.external_tool_by_name("RunSql")).to eq(
        DiscourseDataExplorer::Tools::RunSql,
      )
    end
  end

  describe ".system_agents_by_id" do
    it "includes external agents discovered from the raw plugin registry" do
      expect(described_class.system_agents_by_id[expected_agent_id]).to eq(
        DiscourseDataExplorer::AiQueryGenerator,
      )
    end
  end

  describe "external feature discovery" do
    before { SiteSetting.data_explorer_enabled = false }

    it "discovers agents and tools from the raw registry even when the plugin is disabled" do
      expect(
        DiscoursePluginRegistry.external_ai_features.none? do |e|
          e[:module_name] == :data_explorer
        end,
      ).to eq(true)

      expect(
        DiscoursePluginRegistry._raw_external_ai_features.any? do |e|
          e[:value][:module_name] == :data_explorer
        end,
      ).to eq(true)

      expect(described_class.system_agents[DiscourseDataExplorer::AiQueryGenerator]).to eq(
        expected_agent_id,
      )
      expect(described_class.external_tool_by_name("ValidateSql")).to eq(
        DiscourseDataExplorer::Tools::ValidateSql,
      )
      expect(described_class.external_tool_by_name("RunSql")).to eq(
        DiscourseDataExplorer::Tools::RunSql,
      )
    end
  end
end

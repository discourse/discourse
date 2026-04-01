# frozen_string_literal: true

describe DiscourseAi::Agents::Agent do
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

  describe "RESERVED_EXTERNAL_IDS" do
    it "includes data_explorer with module and feature IDs" do
      de = described_class::RESERVED_EXTERNAL_IDS[:data_explorer]
      expect(de[:module_id]).to eq(1001)
      expect(de.dig(:features, :query_generation, :agent_id)).to eq(-1001)
    end
  end

  describe ".system_agents_by_id" do
    it "includes external agents discovered from the raw plugin registry" do
      expect(described_class.system_agents_by_id[-1001]).to eq(
        DiscourseDataExplorer::AiQueryGenerator,
      )
    end
  end
end

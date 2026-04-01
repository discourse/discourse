# frozen_string_literal: true

describe DiscourseAi::Configuration::ExternalFeatureSetup do
  before { SiteSetting.data_explorer_enabled = false }

  it "discovers external agents and tools from the raw registry even when the plugin is disabled" do
    expect(
      DiscoursePluginRegistry.external_ai_features.none? do |entry|
        entry[:module_name] == :data_explorer
      end,
    ).to eq(true)

    expect(
      DiscoursePluginRegistry._raw_external_ai_features.any? do |entry|
        entry[:value][:module_name] == :data_explorer
      end,
    ).to eq(true)

    expect(DiscourseAi::Agents::Agent.system_agents[DiscourseDataExplorer::AiQueryGenerator]).to eq(
      DiscourseAi::Agents::Agent::RESERVED_EXTERNAL_IDS.dig(
        :data_explorer,
        :features,
        :query_generation,
        :agent_id,
      ),
    )
    expect(DiscourseAi::Agents::Agent.external_tool_by_name("ValidateSql")).to eq(
      DiscourseDataExplorer::Tools::ValidateSql,
    )
    expect(DiscourseAi::Agents::Agent.external_tool_by_name("RunSql")).to eq(
      DiscourseDataExplorer::Tools::RunSql,
    )
  end
end

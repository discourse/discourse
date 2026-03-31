# frozen_string_literal: true

describe DiscourseAi::Configuration::ExternalFeatureSetup do
  before do
    SiteSetting.data_explorer_enabled = false
    described_class.instance_variable_set(:@setup_done, nil)

    DiscourseAi::Agents::Agent.system_agents.delete(DiscourseDataExplorer::AiQueryGenerator)
    DiscourseAi::Agents::Agent.instance_variable_set(:@system_agents_by_id, nil)
    DiscourseAi::Agents::Agent.registered_tools.delete("ValidateSql")
    DiscourseAi::Agents::Agent.registered_tools.delete("RunSql")
  end

  it "registers external agents and tools even when the plugin is disabled" do
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

    described_class.ensure_setup!

    expect(DiscourseAi::Agents::Agent.system_agents[DiscourseDataExplorer::AiQueryGenerator]).to eq(
      DiscourseAi::Agents::Agent::RESERVED_EXTERNAL_IDS.dig(
        :data_explorer,
        :features,
        :query_generation,
        :agent_id,
      ),
    )
    expect(DiscourseAi::Agents::Agent.registered_tools["ValidateSql"]).to eq(
      DiscourseDataExplorer::Tools::ValidateSql,
    )
    expect(DiscourseAi::Agents::Agent.registered_tools["RunSql"]).to eq(
      DiscourseDataExplorer::Tools::RunSql,
    )
  end
end

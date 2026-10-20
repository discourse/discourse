# frozen_string_literal: true

describe DiscourseAi::Agents::AskAiReporter do
  it "declares the nested subject output used by the report generator" do
    properties =
      DiscourseAi::Agents::Bot.json_schema_properties(described_class.new.response_format)

    expect(properties.fetch(:summary)).to eq(type: "string")
    subjects = properties.fetch(:subjects)
    expect(subjects[:type]).to eq("array")
    expect(subjects[:maxItems]).to eq(8)
    expect(subjects[:items]).to include(
      type: "object",
      required: %w[name description ask_ids],
      additionalProperties: false,
      properties: {
        name: {
          type: "string",
        },
        description: {
          type: "string",
        },
        ask_ids: {
          type: "array",
          items: {
            type: "integer",
          },
        },
      },
    )
  end

  it "registers the reporting agent without exposing task agents to AI bot" do
    expect(DiscourseAi::Agents::Agent.system_agents.fetch(described_class)).to eq(-42)
    expect(SiteSetting.ai_ask_ai_report_agent).to eq("-42")
    expect(described_class.new.tools).to eq([])
    [
      described_class,
      DiscourseAi::Agents::AskAiQueryRewriter,
      DiscourseAi::Agents::AskAiSynthesis,
    ].each { |agent_class| expect(agent_class.default_enabled).to eq(false) }
    expect(AiAgent.all_agents.map(&:id)).not_to include(-40, -41, -42)
  end
end

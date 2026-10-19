# frozen_string_literal: true

describe DiscourseAi::Agents::AskAiSynthesis do
  subject(:agent) { described_class.new }

  it "defines the fixed Ask AI response contract" do
    SiteSetting.ai_ask_ai_related_count = 4

    expect(DiscourseAi::Agents::Agent.system_agents.fetch(described_class)).to eq(-41)
    expect(SiteSetting.ai_ask_ai_agent).to eq("-41")
    expect(agent.response_format).to eq(
      [
        { "key" => "answerable", "type" => "boolean" },
        { "key" => "source_refs", "type" => "array", "array_type" => "string", "max_items" => 4 },
        { "key" => "title", "type" => "string" },
        { "key" => "answer", "type" => "string" },
        { "key" => "follow_up", "type" => "string" },
      ],
    )
  end
end

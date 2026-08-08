# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::ShortSummarizer do
  subject(:agent) { described_class.new }

  it "uses the set_topic_summary tool instead of structured output" do
    expect(agent.response_format).to be_nil
    expect(agent.available_tools).to contain_exactly(DiscourseAi::Agents::Tools::SetTopicSummary)
    expect(agent.force_tool_use).to eq(agent.available_tools)
    expect(agent.system_prompt).to include("Call the set_topic_summary tool exactly once")
    expect(agent.system_prompt).not_to include("JSON")
  end
end

# frozen_string_literal: true

describe DiscourseAi::Agents::Discover do
  subject(:agent) { described_class.new }

  it "uses the existing Search and Read tools" do
    expect(agent.tools).to contain_exactly(
      DiscourseAi::Agents::Tools::Read,
      DiscourseAi::Agents::Tools::Search,
    )
    expect(agent.required_tools).to eq([DiscourseAi::Agents::Tools::Search])
    expect(agent.force_tool_use).to eq([DiscourseAi::Agents::Tools::Search])
    expect(agent.forced_tool_count).to eq(1)
  end
end

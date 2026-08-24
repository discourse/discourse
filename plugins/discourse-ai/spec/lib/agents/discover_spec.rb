# frozen_string_literal: true

describe DiscourseAi::Agents::Discover do
  subject(:agent) { described_class.new }

  it "defines the fixed Discoveries response contract" do
    SiteSetting.ai_discover_related_count = 4

    expect(agent.response_format).to eq(
      [
        { "key" => "answerable", "type" => "boolean" },
        { "key" => "source_refs", "type" => "array", "array_type" => "string", "max_items" => 4 },
        { "key" => "title", "type" => "string" },
        { "key" => "answer", "type" => "string" },
      ],
    )
  end
end

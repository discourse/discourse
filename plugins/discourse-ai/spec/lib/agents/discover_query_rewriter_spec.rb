# frozen_string_literal: true

describe DiscourseAi::Agents::DiscoverQueryRewriter do
  subject(:agent) { described_class.new }

  it "prepares separate PostgreSQL and semantic search queries without changing intent" do
    expect(DiscourseAi::Agents::Agent.system_agents.fetch(described_class)).to eq(-40)
    expect(SiteSetting.ai_discover_query_rewrite_agent).to eq("-40")
    expect(agent.response_format).to eq(
      [
        { "key" => "keyword_query", "type" => "string" },
        { "key" => "semantic_query", "type" => "string" },
        { "key" => "original_query_locale", "type" => "string" },
      ],
    )
    expect(agent.examples).to include(
      [
        { query: "怎么删除具备管理员权限的幽灵机器人用户？", forum_default_locale: "en" }.to_json,
        {
          keyword_query: "delete admin bot user",
          semantic_query: "how to remove a bot account that has administrator permissions",
          original_query_locale: "zh_CN",
        }.to_json,
      ],
      [
        {
          query: "What are the 3 most popular topics on the forum?",
          forum_default_locale: "en",
        }.to_json,
        { keyword_query: "order:likes", semantic_query: "", original_query_locale: "en" }.to_json,
      ],
      [
        { query: "@nat l logs", forum_default_locale: "en" }.to_json,
        { keyword_query: "@nat l logs", semantic_query: "", original_query_locale: "en" }.to_json,
      ],
    )
  end
end

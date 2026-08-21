# frozen_string_literal: true

describe DiscourseAi::Agents::DiscoverQueryRewriter do
  subject(:agent) { described_class.new }

  it "prepares separate PostgreSQL and semantic search queries without changing intent" do
    expect(DiscourseAi::Agents::Agent.system_agents.fetch(described_class)).to eq(-40)
    expect(SiteSetting.ai_discover_query_rewrite_agent).to eq("-40")
    expect(agent.system_prompt).to include("PostgreSQL-backed keyword search")
    expect(agent.system_prompt).to include("admin")
    expect(agent.system_prompt).to include("forum's default locale")
    expect(agent.system_prompt).to include("must not broaden, narrow, or reinterpret")
    expect(agent.response_format).to eq(
      [
        { "key" => "keyword_query", "type" => "string" },
        { "key" => "semantic_query", "type" => "string" },
      ],
    )
    expect(agent.examples).to include(
      [
        { query: "怎么删除具备管理员权限的幽灵机器人用户？", forum_default_locale: "en" }.to_json,
        {
          keyword_query: "delete admin bot user",
          semantic_query: "how to remove a bot account that has administrator permissions",
        }.to_json,
      ],
    )
  end
end

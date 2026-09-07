# frozen_string_literal: true

describe DiscourseAi::Agents::AskAiQueryRewriter do
  subject(:agent) { described_class.new }

  it "prepares separate PostgreSQL and semantic search queries without changing intent" do
    expect(DiscourseAi::Agents::Agent.system_agents.fetch(described_class)).to eq(-40)
    expect(SiteSetting.ai_ask_ai_query_rewriter_agent).to eq("-40")
    expect(agent.response_format).to eq(
      [
        { "key" => "keyword_query", "type" => "string" },
        { "key" => "semantic_query", "type" => "string" },
        { "key" => "original_query_locale", "type" => "string" },
      ],
    )
    expect(agent.examples).to eq(
      [
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
            query: "What are the most popular topics since January 1, 2026?",
            forum_default_locale: "en",
          }.to_json,
          {
            keyword_query: "after:2026-01-01 order:likes",
            semantic_query: "",
            original_query_locale: "en",
          }.to_json,
        ],
        [
          { query: "@nat l logs", forum_default_locale: "en" }.to_json,
          { keyword_query: "@nat l logs", semantic_query: "", original_query_locale: "en" }.to_json,
        ],
        [
          { query: "Which of my PMs discuss anime?", forum_default_locale: "en" }.to_json,
          {
            keyword_query: "anime in:messages",
            semantic_query: "private conversations about anime",
            original_query_locale: "en",
          }.to_json,
        ],
      ],
    )
  end
end

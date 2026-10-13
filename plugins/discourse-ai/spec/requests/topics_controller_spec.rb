# frozen_string_literal: true

RSpec.describe TopicsController do
  fab!(:user)
  fab!(:post)

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = false
  end

  describe "#show" do
    before { sign_in(user) }

    it "preloads agent MCP assignments for an HTML request when the bot is disabled" do
      get post.topic.relative_url
      expect(response.status).to eq(200)

      agents = []
      mcp_query_counts =
        [1, 2].map do |agent_count|
          (agent_count - agents.size).times do
            agents << Fabricate(
              :ai_agent,
              user: Fabricate(:user),
              enabled: true,
              allowed_group_ids: [Group::AUTO_GROUPS[:everyone]],
              tools: [],
            )
          end
          AiAgent.agent_cache.flush!

          queries = track_sql_queries { get post.topic.relative_url }

          expect(response.status).to eq(200)
          expect(response.media_type).to eq("text/html")
          preloaded = JSON.parse(css_select("script#data-preloaded").first.text)
          current_user = JSON.parse(preloaded["currentUser"])
          expect(current_user["ai_enabled_agents"].map { |agent| agent["id"] }).to include(
            *agents.map(&:id),
          )
          mcp_queries = queries.grep(/FROM "ai_agent_mcp_servers"/)
          expect(mcp_queries).to be_present

          mcp_queries.size
        end

      expect(mcp_query_counts.last).to eq(mcp_query_counts.first)
    end
  end
end

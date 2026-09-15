# frozen_string_literal: true

RSpec.describe "AI response attribution" do
  fab!(:llm_model) { Fabricate(:llm_model, display_name: "Visible model") }
  fab!(:agent) do
    Fabricate(
      :ai_agent,
      name: "Visible agent",
      allowed_group_ids: [Group::AUTO_GROUPS[:everyone]],
      allow_topic_mentions: true,
      default_llm: llm_model,
    ).tap(&:ensure_user!)
  end
  fab!(:topic)
  fab!(:response_post) do
    Fabricate(
      :post,
      topic:,
      user: agent.user,
      custom_fields: {
        DiscourseAi::AiBot::POST_AI_AGENT_ID_FIELD => agent.id,
        DiscourseAi::AiBot::POST_AI_LLM_MODEL_ID_FIELD => llm_model.id,
        DiscourseAi::AiBot::POST_AI_LLM_NAME_FIELD => llm_model.display_name,
      },
    )
  end

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    response_post
  end

  it "shows agent and model attribution to anonymous readers" do
    visit topic.relative_url

    within("article[data-post-id='#{response_post.id}'] .names") do
      expect(page).to have_css(".agent-flair", text: agent.name)
      expect(page).to have_css(".agent-flair__model", text: llm_model.display_name)
      expect(page).to have_no_text(agent.user.username)
    end
  end
end

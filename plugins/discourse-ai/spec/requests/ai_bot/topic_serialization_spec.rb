# frozen_string_literal: true

RSpec.describe "AI Bot Post Serializer" do
  fab!(:current_user, :user)
  fab!(:bot_user, :user)

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    sign_in(current_user)
  end

  describe "is_bot_pm in topic_view serializer" do
    it "is included when the PM has the AI bot subtype" do
      pm_topic =
        Fabricate(
          :private_message_topic,
          user: current_user,
          recipient: bot_user,
          subtype: DiscourseAi::AiBot::TOPIC_AI_BOT_PM_SUBTYPE,
        )
      Fabricate(:post, topic: pm_topic, user: current_user)

      get "/t/#{pm_topic.id}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["is_bot_pm"]).to eq(true)
    end
  end

  describe "llm_name in post serializer" do
    it "includes llm_name when custom field is set in a PM" do
      pm_topic = Fabricate(:private_message_topic, user: current_user)

      # Create a bot post with the custom field set
      bot_post =
        Fabricate(
          :post,
          topic: pm_topic,
          user: bot_user,
          custom_fields: {
            DiscourseAi::AiBot::POST_AI_LLM_NAME_FIELD => "bob",
          },
        )

      get "/t/#{pm_topic.id}.json"
      expect(response.status).to eq(200)

      json = response.parsed_body
      bot_post_data = json["post_stream"]["posts"].find { |p| p["id"] == bot_post.id }

      expect(bot_post_data).to have_key("llm_name")
      expect(bot_post_data["llm_name"]).to eq("bob")
    end
  end
end

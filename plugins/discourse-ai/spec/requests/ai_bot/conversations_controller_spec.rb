# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::ConversationsController do
  fab!(:user)
  fab!(:other_user, :user)
  fab!(:bot_user, :user)

  before { enable_current_plugin }

  def fabricate_pm(user:, recipient:, subtype: TopicSubtype.user_to_user, custom_fields: {})
    topic = Fabricate(:private_message_topic, user: user, recipient: recipient, subtype: subtype)
    Fabricate(:post, topic: topic, user: user)
    custom_fields.each { |name, value| topic.custom_fields[name] = value }
    topic.save_custom_fields if custom_fields.present?
    topic
  end

  describe "GET index" do
    it "requires login" do
      get "/discourse-ai/ai-bot/conversations.json"

      expect(response.status).to eq(403)
    end

    it "returns authored AI bot conversations" do
      sign_in(user)

      ai_conversation =
        fabricate_pm(
          user: user,
          recipient: bot_user,
          subtype: DiscourseAi::AiBot::TOPIC_AI_BOT_PM_SUBTYPE,
        )
      old_marker_conversation =
        fabricate_pm(
          user: user,
          recipient: bot_user,
          custom_fields: {
            DiscourseAi::AiBot::TOPIC_AI_BOT_PM_FIELD => "t",
          },
        )
      fabricate_pm(user: user, recipient: other_user)
      fabricate_pm(
        user: other_user,
        recipient: user,
        subtype: DiscourseAi::AiBot::TOPIC_AI_BOT_PM_SUBTYPE,
      )

      get "/discourse-ai/ai-bot/conversations.json"

      topic_ids = response.parsed_body["conversations"].map { |topic| topic["id"] }
      expect(topic_ids).to contain_exactly(ai_conversation.id, old_marker_conversation.id)
      expect(response.parsed_body["meta"]).to include("total" => 2, "page" => 0)
    end
  end
end

# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::ConversationsController do
  fab!(:current_user, :user)
  fab!(:other_user, :user)
  fab!(:bot_user, :user)
  fab!(:conversation) do
    Fabricate(:private_message_topic, user: current_user, recipient: bot_user, title: "AI PM")
  end
  fab!(:starred_conversation) do
    Fabricate(
      :private_message_topic,
      user: current_user,
      recipient: bot_user,
      title: "Starred AI PM",
    )
  end
  fab!(:other_conversation) do
    Fabricate(:private_message_topic, user: other_user, recipient: bot_user, title: "Other AI PM")
  end
  fab!(:normal_pm) { Fabricate(:private_message_topic, user: current_user, recipient: other_user) }
  fab!(:regular_topic, :topic)

  before do
    enable_current_plugin
    sign_in(current_user)
    [conversation, starred_conversation, other_conversation].each { |topic| mark_ai_bot_pm(topic) }
  end

  describe "GET /discourse-ai/ai-bot/conversations.json" do
    before do
      DiscourseAi::AiBot::ConversationStar.create!(user: current_user, topic: starred_conversation)
      DiscourseAi::AiBot::ConversationStar.create!(user: other_user, topic: other_conversation)
    end

    it "returns starred conversations first" do
      get "/discourse-ai/ai-bot/conversations.json"

      expect(response.status).to eq(200)
      json = response.parsed_body

      expect(json).not_to have_key("starred_conversations")
      expect(json["conversations"].first["id"]).to eq(starred_conversation.id)
      expect(json["conversations"].first["ai_conversation_starred"]).to eq(true)
      expect(json["conversations"].map { |topic| topic["id"] }).to include(conversation.id)
      expect(json["conversations"].map { |topic| topic["id"] }).not_to include(normal_pm.id)
      expect(json["conversations"].map { |topic| topic["id"] }).not_to include(
        other_conversation.id,
      )
    end

    it "caps starred conversations returned on the first page" do
      extra_starred_conversations =
        2.times.map do |index|
          topic =
            Fabricate(
              :private_message_topic,
              user: current_user,
              recipient: bot_user,
              title: "Extra starred AI PM #{index}",
            )
          mark_ai_bot_pm(topic)
          DiscourseAi::AiBot::ConversationStar.create!(user: current_user, topic: topic)
          topic
        end

      stub_const(DiscourseAi::AiBot::ConversationStar, :MAX_STARS_PER_USER, 2) do
        get "/discourse-ai/ai-bot/conversations.json"
      end

      expect(response.status).to eq(200)
      starred_records =
        response.parsed_body["conversations"].select { |topic| topic["ai_conversation_starred"] }
      expect(starred_records.length).to eq(2)
      expect(starred_records.map { |topic| topic["id"] }).to all(
        be_in([starred_conversation.id, *extra_starred_conversations.map(&:id)]),
      )
    end
  end

  describe "PUT /discourse-ai/ai-bot/conversations/:topic_id/starred.json" do
    it "stars a conversation for the current user" do
      put "/discourse-ai/ai-bot/conversations/#{conversation.id}/starred.json",
          params: {
            starred: true,
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["starred"]).to eq(true)
      expect(
        DiscourseAi::AiBot::ConversationStar.exists?(user: current_user, topic: conversation),
      ).to eq(true)
    end

    it "does not honor a supplied user_id" do
      put "/discourse-ai/ai-bot/conversations/#{conversation.id}/starred.json",
          params: {
            starred: true,
            user_id: other_user.id,
          }

      expect(response.status).to eq(200)
      expect(
        DiscourseAi::AiBot::ConversationStar.exists?(user: current_user, topic: conversation),
      ).to eq(true)
      expect(
        DiscourseAi::AiBot::ConversationStar.exists?(user: other_user, topic: conversation),
      ).to eq(false)
    end

    it "is idempotent when starring" do
      DiscourseAi::AiBot::ConversationStar.create!(user: current_user, topic: conversation)

      expect do
        put "/discourse-ai/ai-bot/conversations/#{conversation.id}/starred.json",
            params: {
              starred: true,
            }
      end.not_to change { DiscourseAi::AiBot::ConversationStar.count }

      expect(response.status).to eq(200)
    end

    it "unstars a conversation for only the current user" do
      DiscourseAi::AiBot::ConversationStar.create!(user: current_user, topic: conversation)
      DiscourseAi::AiBot::ConversationStar.create!(user: other_user, topic: conversation)

      put "/discourse-ai/ai-bot/conversations/#{conversation.id}/starred.json",
          params: {
            starred: false,
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["starred"]).to eq(false)
      expect(
        DiscourseAi::AiBot::ConversationStar.exists?(user: current_user, topic: conversation),
      ).to eq(false)
      expect(
        DiscourseAi::AiBot::ConversationStar.exists?(user: other_user, topic: conversation),
      ).to eq(true)
    end

    it "is idempotent when unstarring" do
      expect do
        put "/discourse-ai/ai-bot/conversations/#{conversation.id}/starred.json",
            params: {
              starred: false,
            }
      end.not_to change { DiscourseAi::AiBot::ConversationStar.count }

      expect(response.status).to eq(200)
    end

    it "rejects a missing starred param" do
      put "/discourse-ai/ai-bot/conversations/#{conversation.id}/starred.json"

      expect(response.status).to eq(400)
    end

    it "returns 404 for a non-existent topic" do
      put "/discourse-ai/ai-bot/conversations/99999999/starred.json", params: { starred: true }

      expect(response.status).to eq(404)
    end

    it "returns 404 and does not star another user's AI bot PM" do
      put "/discourse-ai/ai-bot/conversations/#{other_conversation.id}/starred.json",
          params: {
            starred: true,
          }

      expect(response.status).to eq(404)
      expect(
        DiscourseAi::AiBot::ConversationStar.exists?(user: current_user, topic: other_conversation),
      ).to eq(false)
    end

    it "returns 404 and does not star a non-AI PM" do
      put "/discourse-ai/ai-bot/conversations/#{normal_pm.id}/starred.json",
          params: {
            starred: true,
          }

      expect(response.status).to eq(404)
      expect(
        DiscourseAi::AiBot::ConversationStar.exists?(user: current_user, topic: normal_pm),
      ).to eq(false)
    end

    it "returns 404 and does not star a regular topic" do
      put "/discourse-ai/ai-bot/conversations/#{regular_topic.id}/starred.json",
          params: {
            starred: true,
          }

      expect(response.status).to eq(404)
      expect(
        DiscourseAi::AiBot::ConversationStar.exists?(user: current_user, topic: regular_topic),
      ).to eq(false)
    end
  end

  def mark_ai_bot_pm(topic)
    topic.custom_fields[DiscourseAi::AiBot::TOPIC_AI_BOT_PM_FIELD] = "t"
    topic.save!
  end
end

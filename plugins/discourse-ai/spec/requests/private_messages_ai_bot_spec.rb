# frozen_string_literal: true

RSpec.describe "Bot Chats inbox" do
  fab!(:bot_user) { Fabricate(:user, id: -1500, username: "test_bot", refresh_auto_groups: true) }
  fab!(:human) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:other_human) { Fabricate(:user, refresh_auto_groups: true) }

  fab!(:bot_pm) do
    topic =
      create_post(
        user: human,
        target_usernames: [bot_user.username],
        archetype: Archetype.private_message,
      ).topic

    # Reply from the bot so the topic survives the
    # `have_posts_from_others` filter applied by Latest.
    create_post(user: bot_user, topic_id: topic.id)
    topic.update_statistics!
    topic.reload
  end

  fab!(:human_pm) do
    topic =
      create_post(
        user: human,
        target_usernames: [other_human.username],
        archetype: Archetype.private_message,
      ).topic

    create_post(user: other_human, topic_id: topic.id)
    topic.update_statistics!
    topic.reload
  end

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    bot_pm.custom_fields[DiscourseAi::AiBot::TOPIC_AI_BOT_PM_FIELD] = "t"
    bot_pm.save_custom_fields
  end

  describe "GET /topics/private-messages-ai-bot/:username" do
    it "returns only bot PMs the user is allowed to see" do
      sign_in(human)

      get "/topics/private-messages-ai-bot/#{human.username}.json"

      expect(response.status).to eq(200)
      topic_ids = response.parsed_body.dig("topic_list", "topics").map { |t| t["id"] }
      expect(topic_ids).to contain_exactly(bot_pm.id)
    end

    it "is self-only — refuses requests for another user's bot inbox" do
      sign_in(other_human)

      get "/topics/private-messages-ai-bot/#{human.username}.json"

      expect(response.status).to eq(404)
    end

    it "requires authentication" do
      get "/topics/private-messages-ai-bot/#{human.username}.json"

      expect(response.status).to eq(403)
    end
  end

  describe "personal inbox filtering" do
    it "hides bot PMs from #list_private_messages (Latest)" do
      topics = TopicQuery.new(human).list_private_messages(human).topics

      expect(topics).to include(human_pm)
      expect(topics).not_to include(bot_pm)
    end

    it "keeps bot PMs visible in #list_private_messages_archive" do
      [human_pm, bot_pm].each { |t| UserArchivedMessage.archive!(human.id, t) }

      topics = TopicQuery.new(human).list_private_messages_archive(human).topics

      expect(topics).to include(human_pm, bot_pm)
    end

    it "keeps bot PMs visible in #list_private_messages_sent" do
      topics = TopicQuery.new(human).list_private_messages_sent(human).topics

      expect(topics).to include(human_pm, bot_pm)
    end
  end

  describe "TopicQuery#list_private_messages_ai_bot" do
    it "returns only bot PMs that the user participates in" do
      topics = TopicQuery.new(human).list_private_messages_ai_bot(human).topics

      expect(topics).to contain_exactly(bot_pm)
    end

    it "ignores archived bot PMs" do
      UserArchivedMessage.archive!(human.id, bot_pm)

      topics = TopicQuery.new(human).list_private_messages_ai_bot(human).topics

      expect(topics).to be_empty
    end
  end
end

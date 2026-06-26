# frozen_string_literal: true

RSpec.describe "AI bot conversation creation" do
  fab!(:current_user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:other_user, :user)
  fab!(:llm_model) { Fabricate(:llm_model, name: "gpt-4") }

  before do
    enable_current_plugin
    toggle_enabled_bots(bots: [llm_model])
    SiteSetting.ai_bot_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
    SiteSetting.personal_message_enabled_groups = Group::AUTO_GROUPS[:staff]
    sign_in(current_user)
  end

  it "denies regular PM creation" do
    expect do
      post "/posts.json",
           params: {
             raw: "This normal personal message should not be created.",
             title: "Normal personal message",
             archetype: Archetype.private_message,
             target_recipients: other_user.username,
           }
    end.not_to change { Topic.private_messages_for_user(current_user).count }

    expect(response.status).to eq(422)
    expect(response.parsed_body["errors"]).to include(
      I18n.t("activerecord.errors.models.topic.attributes.base.cant_send_pm"),
    )

    expect do
      post "/discourse-ai/ai-bot/conversations.json",
           params: {
             raw: "This bot conversation route must not create a regular PM.",
             target_username: other_user.username,
           }
    end.not_to change { Topic.private_messages_for_user(current_user).count }

    expect(response.status).to eq(403)
  end

  it "keeps regular AI bot PM creation denied through the posts endpoint" do
    bot_user = llm_model.reload.user

    expect do
      post "/posts.json",
           params: {
             raw: "This AI bot personal message should not be created through posts.",
             title: "AI bot personal message",
             archetype: Archetype.private_message,
             target_recipients: bot_user.username,
           }
    end.not_to change { Topic.private_messages_for_user(current_user).count }

    expect(response.status).to eq(422)
    expect(response.parsed_body["errors"]).to include(
      I18n.t("activerecord.errors.models.topic.attributes.base.cant_send_pm"),
    )
  end

  it "allows creating and using an AI bot conversation" do
    bot_user = llm_model.reload.user

    expect do
      post "/discourse-ai/ai-bot/conversations.json",
           params: {
             raw: "Please help me with this AI bot conversation.",
             target_username: bot_user.username,
           }
    end.to change { Topic.private_messages_for_user(current_user).count }.by(1)

    expect(response.status).to eq(200)
    topic = Topic.find(response.parsed_body["topic_id"])
    expect(topic.allowed_users).to contain_exactly(current_user, bot_user)
    expect(topic.custom_fields[DiscourseAi::AiBot::TOPIC_AI_BOT_PM_FIELD]).to eq("t")

    get "/discourse-ai/ai-bot/conversations.json"

    expect(response.status).to eq(200)
    expect(
      response.parsed_body["conversations"].map { |conversation| conversation["id"] },
    ).to include(topic.id)

    post "/posts.json",
         params: {
           raw: "Here is a follow-up message for the AI bot.",
           topic_id: topic.id,
         }

    expect(response.status).to eq(200)
    expect(response.parsed_body["topic_id"]).to eq(topic.id)
  end

  it "uses AI bot access settings for bot conversations" do
    SiteSetting.ai_bot_allowed_groups = Group::AUTO_GROUPS[:staff]
    bot_user = llm_model.reload.user

    expect do
      post "/discourse-ai/ai-bot/conversations.json",
           params: {
             raw: "Please help me with this AI bot conversation.",
             target_username: bot_user.username,
           }
    end.not_to change { Topic.private_messages_for_user(current_user).count }

    expect(response.status).to eq(403)
  end
end

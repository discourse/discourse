# frozen_string_literal: true

RSpec.describe "AI bot conversation creation" do
  fab!(:current_user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:other_user, :user)
  fab!(:llm_model) { Fabricate(:llm_model, name: "gpt-4") }
  fab!(:agent) do
    Fabricate(
      :ai_agent,
      allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
      allow_personal_messages: true,
      default_llm: llm_model,
    ).tap(&:ensure_user!)
  end

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

    expect(response.status).to eq(422)
  end

  it "keeps direct agent PM creation denied through the posts endpoint" do
    expect do
      post "/posts.json",
           params: {
             raw: "This AI bot personal message should not be created through posts.",
             title: "AI bot personal message",
             archetype: Archetype.private_message,
             target_recipients: agent.user.username,
           }
    end.not_to change { Topic.private_messages_for_user(current_user).count }

    expect(response.status).to eq(422)
    expect(response.parsed_body["errors"]).to include(
      I18n.t("activerecord.errors.models.topic.attributes.base.cant_send_pm"),
    )
  end

  it "creates an agent-owned conversation with an explicit model" do
    expect do
      post "/discourse-ai/ai-bot/conversations.json",
           params: {
             raw: "Please help me with this AI bot conversation.",
             target_username: agent.user.username,
             ai_agent_id: agent.id,
             ai_llm_model_id: llm_model.id,
           }
    end.to change { Topic.private_messages_for_user(current_user).count }.by(1)

    expect(response.status).to eq(200)
    topic = Topic.find(response.parsed_body["topic_id"])
    expect(topic.allowed_users).to contain_exactly(current_user, agent.user)
    expect(topic.custom_fields).to include(
      DiscourseAi::AiBot::TOPIC_AI_BOT_PM_FIELD => "t",
      DiscourseAi::AiBot::TOPIC_AI_AGENT_ID_FIELD => agent.id.to_s,
      DiscourseAi::AiBot::TOPIC_AI_LLM_MODEL_ID_FIELD => llm_model.id.to_s,
    )

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

  it "creates a conversation with the configured agent default outside the public picker" do
    selectable_model = Fabricate(:llm_model)
    toggle_enabled_bots(bots: [selectable_model])

    expect do
      post "/discourse-ai/ai-bot/conversations.json",
           params: {
             raw: "Use the agent's configured model.",
             target_username: agent.user.username,
             ai_agent_id: agent.id,
           }
    end.to change { Topic.private_messages_for_user(current_user).count }.by(1)

    expect(response).to have_http_status(:ok)
    topic = Topic.find(response.parsed_body["topic_id"])
    expect(topic.custom_fields[DiscourseAi::AiBot::TOPIC_AI_LLM_MODEL_ID_FIELD].to_i).to eq(
      llm_model.id,
    )
  end

  it "normalizes a legacy model recipient to the General agent" do
    legacy_user = Fabricate(:user, id: DiscourseAi::BotUser.next_id)
    llm_model.update_column(:user_id, legacy_user.id)
    general_agent =
      AiAgent.find(DiscourseAi::Agents::Agent.system_agents[DiscourseAi::Agents::General])
    general_agent.update!(
      allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
      default_llm: llm_model,
    )
    general_agent.ensure_user!

    expect do
      post "/discourse-ai/ai-bot/conversations.json",
           params: {
             raw: "Continue this legacy model conversation.",
             target_username: legacy_user.username,
           }
    end.to change { Topic.private_messages_for_user(current_user).count }.by(1)

    expect(response).to have_http_status(:ok)
    topic = Topic.find(response.parsed_body["topic_id"])
    expect(topic.allowed_users).to contain_exactly(current_user, general_agent.user)
    expect(topic.custom_fields).to include(
      DiscourseAi::AiBot::TOPIC_AI_AGENT_ID_FIELD => general_agent.id.to_s,
      DiscourseAi::AiBot::TOPIC_AI_LLM_MODEL_ID_FIELD => llm_model.id.to_s,
    )
  end

  it "rejects a PM-enabled agent with a missing speaker" do
    unavailable_agent =
      Fabricate(
        :ai_agent,
        allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
        allow_personal_messages: true,
        default_llm: llm_model,
      )

    expect do
      post "/discourse-ai/ai-bot/conversations.json",
           params: {
             raw: "Please run this PM-enabled agent in a bot conversation.",
             target_username: other_user.username,
             ai_agent_id: unavailable_agent.id,
             ai_llm_model_id: llm_model.id,
           }
    end.not_to change { Topic.private_messages_for_user(current_user).count }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body["errors"]).to include(
      I18n.t("discourse_ai.ai_bot.errors.no_user_for_agent"),
    )
  end

  it "rejects a forged agent that is unavailable for personal messages" do
    forged_agent =
      Fabricate(
        :ai_agent,
        allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
        allow_personal_messages: false,
      )

    expect do
      post "/discourse-ai/ai-bot/conversations.json",
           params: {
             raw: "Please run this forged agent in a bot conversation.",
             target_username: agent.user.username,
             ai_agent_id: forged_agent.id,
             ai_llm_model_id: llm_model.id,
           }
    end.not_to change { Topic.private_messages_for_user(current_user).count }

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "uses AI bot access settings for bot conversations" do
    SiteSetting.ai_bot_allowed_groups = Group::AUTO_GROUPS[:staff]

    expect do
      post "/discourse-ai/ai-bot/conversations.json",
           params: {
             raw: "Please help me with this AI bot conversation.",
             target_username: agent.user.username,
             ai_agent_id: agent.id,
             ai_llm_model_id: llm_model.id,
           }
    end.not_to change { Topic.private_messages_for_user(current_user).count }

    expect(response).to have_http_status(:unprocessable_entity)
  end
end

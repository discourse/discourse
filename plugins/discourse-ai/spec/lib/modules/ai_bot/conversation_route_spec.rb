# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::ConversationRoute do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:first_model) { Fabricate(:llm_model, display_name: "First model") }
  fab!(:second_model) { Fabricate(:llm_model, display_name: "Second model") }
  fab!(:agent) do
    Fabricate(
      :ai_agent,
      allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
      allow_personal_messages: true,
      default_llm: first_model,
    ).tap(&:ensure_user!)
  end

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    SiteSetting.ai_bot_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
    SiteSetting.ai_bot_enabled_llms = [first_model.id, second_model.id].join("|")
  end

  it "resolves the agent speaker independently from an explicit model" do
    route =
      described_class.resolve(
        authorization_user: user,
        modality: :personal_message,
        agent_id: agent.id,
        llm_model_id: second_model.id,
        recipient_user: agent.user,
      )

    expect(route.speaker).to eq(agent.user)
    expect(route.model).to eq(second_model)
    expect(route.model_source).to eq(:request)
  end

  it "uses and validates a topic model default" do
    topic = Fabricate(:private_message_topic, user: user, recipient: agent.user)
    topic.custom_fields[DiscourseAi::AiBot::TOPIC_AI_AGENT_ID_FIELD] = agent.id
    topic.custom_fields[DiscourseAi::AiBot::TOPIC_AI_LLM_MODEL_ID_FIELD] = second_model.id
    topic.save_custom_fields

    route =
      described_class.resolve(authorization_user: user, modality: :personal_message, topic: topic)
    expect(route.model).to eq(second_model)

    SiteSetting.ai_bot_enabled_llms = first_model.id.to_s
    expect do
      described_class.resolve(authorization_user: user, modality: :personal_message, topic: topic)
    end.to raise_error(
      described_class::Error,
      I18n.t("discourse_ai.ai_bot.errors.model_not_selectable"),
    )
  end

  it "ignores a zero model provenance value during legacy resolution" do
    topic = Fabricate(:private_message_topic, user: user, recipient: agent.user)
    topic.custom_fields[DiscourseAi::AiBot::TOPIC_AI_AGENT_ID_FIELD] = agent.id
    topic.save_custom_fields
    Fabricate(
      :post,
      topic:,
      user: agent.user,
      custom_fields: {
        DiscourseAi::AiBot::POST_AI_LLM_MODEL_ID_FIELD => "0",
      },
    )

    route =
      described_class.resolve(authorization_user: user, modality: :personal_message, topic: topic)

    expect(route.model).to eq(first_model)
    expect(route.model_source).to eq(:agent_default)
  end

  it "enforces a forced agent model for requests and snapshots" do
    agent.update!(force_default_llm: true)

    expect do
      described_class.resolve(
        authorization_user: user,
        modality: :personal_message,
        agent_id: agent.id,
        llm_model_id: second_model.id,
      )
    end.to raise_error(
      described_class::Error,
      I18n.t("discourse_ai.ai_bot.errors.model_conflicts_with_agent"),
    )
  end

  it "allows a configured default model outside the public picker" do
    SiteSetting.ai_bot_enabled_llms = second_model.id.to_s

    route =
      described_class.resolve(
        authorization_user: user,
        modality: :personal_message,
        agent_id: agent.id,
      )

    expect(route.model).to eq(first_model)
  end

  it "continues with a persisted configured default outside the public picker" do
    topic = Fabricate(:private_message_topic, user:, recipient: agent.user)
    topic.custom_fields[DiscourseAi::AiBot::TOPIC_AI_AGENT_ID_FIELD] = agent.id
    topic.custom_fields[DiscourseAi::AiBot::TOPIC_AI_LLM_MODEL_ID_FIELD] = first_model.id
    topic.save_custom_fields
    SiteSetting.ai_bot_enabled_llms = second_model.id.to_s

    route =
      described_class.resolve(authorization_user: user, modality: :personal_message, topic: topic)

    expect(route.model).to eq(first_model)
    expect(route.model_source).to eq(:agent_default)
  end

  it "accepts an unchanged configured default sent back by the conversation client" do
    topic = Fabricate(:private_message_topic, user:, recipient: agent.user)
    topic.custom_fields[DiscourseAi::AiBot::TOPIC_AI_AGENT_ID_FIELD] = agent.id
    topic.custom_fields[DiscourseAi::AiBot::TOPIC_AI_LLM_MODEL_ID_FIELD] = first_model.id
    topic.save_custom_fields
    SiteSetting.ai_bot_enabled_llms = second_model.id.to_s

    route =
      described_class.resolve(
        authorization_user: user,
        modality: :personal_message,
        topic:,
        llm_model_id: first_model.id,
        selection_source: :request,
      )

    expect(route.model).to eq(first_model)
    expect(route.model_source).to eq(:agent_default)
  end

  it "continues with a persisted site default outside the public picker" do
    agent.update!(default_llm: nil)
    site_default = assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_bot_enabled_llms = second_model.id.to_s
    topic = Fabricate(:private_message_topic, user:, recipient: agent.user)
    topic.custom_fields[DiscourseAi::AiBot::TOPIC_AI_AGENT_ID_FIELD] = agent.id
    topic.custom_fields[DiscourseAi::AiBot::TOPIC_AI_LLM_MODEL_ID_FIELD] = site_default.id
    topic.save_custom_fields

    route =
      described_class.resolve(authorization_user: user, modality: :personal_message, topic: topic)

    expect(route.model).to eq(site_default)
    expect(route.model_source).to eq(:site_default)
  end

  it "treats a request-supplied legacy model recipient as a selectable model request" do
    legacy_user = Fabricate(:user, id: DiscourseAi::BotUser.next_id)
    second_model.update_column(:user_id, legacy_user.id)

    route =
      described_class.resolve(
        authorization_user: user,
        modality: :personal_message,
        agent_id: agent.id,
        recipient_user: legacy_user,
      )
    expect(route.model).to eq(second_model)
    expect(route.model_source).to eq(:request)

    SiteSetting.ai_bot_enabled_llms = first_model.id.to_s
    expect do
      described_class.resolve(
        authorization_user: user,
        modality: :personal_message,
        agent_id: agent.id,
        recipient_user: legacy_user,
      )
    end.to raise_error(
      described_class::Error,
      I18n.t("discourse_ai.ai_bot.errors.model_not_selectable"),
    )
  end

  it "rejects a recipient that does not belong to the selected agent" do
    expect do
      described_class.resolve(
        authorization_user: user,
        modality: :personal_message,
        agent_id: agent.id,
        llm_model_id: first_model.id,
        recipient_user: Fabricate(:user),
      )
    end.to raise_error(
      described_class::Error,
      I18n.t("discourse_ai.ai_bot.errors.agent_recipient_mismatch"),
    )
  end

  it "resolves trusted automation independently of member bot settings" do
    agent.update!(allowed_group_ids: [Group::AUTO_GROUPS[:staff]])
    SiteSetting.ai_bot_enabled = false

    route =
      described_class.resolve(
        authorization_user: Discourse.system_user,
        modality: :automation,
        agent_id: agent.id,
        allow_general_fallback: false,
      )

    expect(route.speaker).to eq(agent.user)
    expect(route.model).to eq(first_model)
    expect(route.model_source).to eq(:agent_default)
  end

  it "rejects personal messages outside the global access group" do
    SiteSetting.ai_bot_allowed_groups = Group::AUTO_GROUPS[:staff]

    expect do
      described_class.resolve(
        authorization_user: user,
        modality: :personal_message,
        agent_id: agent.id,
      )
    end.to raise_error(described_class::Error, I18n.t("discourse_ai.ai_bot.errors.bot_not_allowed"))
  end
end

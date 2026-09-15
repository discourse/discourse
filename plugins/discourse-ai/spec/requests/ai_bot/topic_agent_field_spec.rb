# frozen_string_literal: true

RSpec.describe "AI agent topic custom field" do
  fab!(:current_user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:llm_model) { Fabricate(:llm_model, name: "gpt-4") }
  fab!(:agent) do
    Fabricate(
      :ai_agent,
      allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
      allow_personal_messages: true,
      default_llm: llm_model,
    ).tap(&:ensure_user!)
  end

  let(:bot_user) { agent.user }

  before do
    enable_current_plugin
    toggle_enabled_bots(bots: [llm_model])
    SiteSetting.ai_bot_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
    SiteSetting.personal_message_enabled_groups = Group::AUTO_GROUPS[:trust_level_0]
    sign_in(current_user)
  end

  def create_pm(ai_agent_id, target_user: bot_user)
    post "/posts.json",
         params: {
           raw: "Hello there, this is a personal message for a bot.",
           title: "Bot personal message",
           archetype: Archetype.private_message,
           target_recipients: target_user.username,
           topic_custom_fields: {
             ai_agent_id: ai_agent_id,
             ai_llm_model_id: llm_model.id,
           },
         }
  end

  it "stores an agent the user is allowed to use in personal messages" do
    create_pm(agent.id)

    expect(response.status).to eq(200)
    topic = Topic.find(response.parsed_body["topic_id"])
    expect(topic.custom_fields["ai_agent_id"]).to eq(agent.id.to_s)
  end

  it "rejects a selected agent that is not a personal-message recipient" do
    create_pm(agent.id, target_user: Fabricate(:user))

    expect(response.status).to eq(422)
    expect(response.parsed_body["errors"]).to include(
      I18n.t("discourse_ai.ai_bot.errors.agent_recipient_mismatch"),
    )
  end

  it "stores a built-in system agent, which has a negative id" do
    system_agent =
      AiAgent.find(DiscourseAi::Agents::Agent.system_agents[DiscourseAi::Agents::General])
    system_agent.update!(
      allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
      allow_personal_messages: true,
      enabled: true,
    )

    system_agent.ensure_user!

    create_pm(system_agent.id, target_user: system_agent.user)

    expect(response.status).to eq(200)
    topic = Topic.find(response.parsed_body["topic_id"])
    expect(topic.custom_fields["ai_agent_id"]).to eq(system_agent.id.to_s)
  end

  it "rejects an agent that is not enabled for personal messages" do
    agent.update!(allow_personal_messages: false)

    create_pm(agent.id)

    expect(response.status).to eq(422)
    expect(response.parsed_body["errors"]).to include(
      I18n.t("discourse_ai.ai_bot.errors.invalid_agent_id"),
    )
    expect(TopicCustomField.where(name: "ai_agent_id").count).to eq(0)
  end

  it "rejects an agent that is not enabled for public-topic mentions" do
    post "/posts.json",
         params: {
           raw: "This topic should not select an unavailable mention agent.",
           title: "Public AI topic",
           topic_custom_fields: {
             ai_agent_id: agent.id,
             ai_llm_model_id: llm_model.id,
           },
         }

    expect(response.status).to eq(422)
    expect(response.parsed_body["errors"]).to include(
      I18n.t("discourse_ai.ai_bot.errors.invalid_agent_id"),
    )
  end

  it "rejects an agent the user is not in the allowed groups for" do
    agent.update!(allowed_group_ids: [Group::AUTO_GROUPS[:staff]])

    create_pm(agent.id)

    expect(response.status).to eq(422)
    expect(response.parsed_body["errors"]).to include(
      I18n.t("discourse_ai.ai_bot.errors.invalid_agent_id"),
    )
    expect(TopicCustomField.where(name: "ai_agent_id").count).to eq(0)
  end

  it "rejects a value that does not identify an agent" do
    create_pm("not-an-agent")

    expect(response.status).to eq(422)
    expect(response.parsed_body["errors"]).to include(
      I18n.t("discourse_ai.ai_bot.errors.invalid_agent_id"),
    )
    expect(TopicCustomField.where(name: "ai_agent_id").count).to eq(0)
  end

  it "rejects an oversized value before it reaches the database" do
    create_pm("a" * 1_000_000)

    expect(response.status).to eq(422)
    expect(response.parsed_body["errors"]).to include(
      I18n.t("custom_fields.validations.max_value_length", max_value_length: 20),
    )
    expect(TopicCustomField.where(name: "ai_agent_id").count).to eq(0)
  end

  it "validates the topic agent id even when post custom fields are also supplied" do
    agent.update!(allow_personal_messages: false)

    creator =
      PostCreator.new(
        current_user,
        title: "Bot personal message",
        raw: "Hello there, this is a personal message for a bot.",
        archetype: Archetype.private_message,
        target_usernames: bot_user.username,
        custom_fields: {
          foo: "bar",
        },
        topic_opts: {
          custom_fields: {
            ai_agent_id: agent.id,
          },
        },
      )

    expect(creator.create).to be_nil
    expect(creator.errors[:base]).to include(I18n.t("discourse_ai.ai_bot.errors.invalid_agent_id"))
    expect(TopicCustomField.where(name: "ai_agent_id")).to be_empty
  end

  it "rejects an unusable agent supplied through the deprecated meta_data param" do
    agent.update!(allow_personal_messages: false)

    post "/posts.json",
         params: {
           raw: "Hello there, this is a personal message for a bot.",
           title: "Bot personal message",
           archetype: Archetype.private_message,
           target_recipients: bot_user.username,
           meta_data: {
             ai_agent_id: agent.id,
           },
         }

    expect(response.status).to eq(422)
    expect(TopicCustomField.where(name: "ai_agent_id").count).to eq(0)
  end

  it "rejects a reply-time model override that conflicts with the topic's forced agent" do
    second_model = Fabricate(:llm_model)
    toggle_enabled_bots(bots: [llm_model, second_model])
    agent.update!(force_default_llm: true)
    create_pm(agent.id)
    topic = Topic.find(response.parsed_body["topic_id"])

    post_count = topic.posts.count
    queued_jobs = Jobs::CreateAiReply.jobs.size
    post "/posts.json",
         params: {
           raw: "Please use a different model for this reply.",
           topic_id: topic.id,
           ai_agent_id: agent.id,
           ai_llm_model_id: second_model.id,
           topic_custom_fields: {
             ai_llm_model_id: second_model.id,
           },
         }

    expect(response).to have_http_status(:ok)
    expect(topic.posts.count).to eq(post_count + 2)
    expect(Jobs::CreateAiReply.jobs.size).to eq(queued_jobs)
    expect(topic.posts.order(:post_number).last.raw).to include(
      I18n.t("discourse_ai.ai_bot.errors.model_conflicts_with_agent"),
    )
    expect(topic.reload.custom_fields[DiscourseAi::AiBot::TOPIC_AI_LLM_MODEL_ID_FIELD].to_i).to eq(
      llm_model.id,
    )
  end

  context "when the PM directly targets an agent's dedicated user" do
    def create_pm_to_agent_user
      post "/posts.json",
           params: {
             raw: "Hello there, this is a personal message for an agent.",
             title: "Agent personal message",
             archetype: Archetype.private_message,
             target_recipients: agent.reload.user.username,
           }
    end

    it "accepts the PM when the agent is accessible and allows personal messages" do
      create_pm_to_agent_user

      expect(response.status).to eq(200)
      topic = Topic.find(response.parsed_body["topic_id"])
      expect(topic.allowed_users).to include(agent.user)
    end

    it "rejects the PM when the agent does not allow personal messages" do
      agent.update!(allow_personal_messages: false)

      create_pm_to_agent_user

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to include(
        I18n.t("discourse_ai.ai_bot.errors.cannot_send_pm_to_agent"),
      )
    end

    it "rejects the PM when the user is not in the agent's allowed groups" do
      agent.update!(allowed_group_ids: [Group::AUTO_GROUPS[:staff]])

      create_pm_to_agent_user

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to include(
        I18n.t("discourse_ai.ai_bot.errors.cannot_send_pm_to_agent"),
      )
    end

    it "rejects a direct PM to a legacy LLM user" do
      legacy_user =
        User.new(
          id: DiscourseAi::BotUser.next_id,
          username: "retired_model",
          email: "retired-model@example.invalid",
          active: true,
        )
      legacy_user.save!(validate: false)
      llm_model.update_columns(user_id: legacy_user.id)

      post "/posts.json",
           params: {
             raw: "Hello there, this is a personal message for a retired bot.",
             title: "Bot personal message",
             archetype: Archetype.private_message,
             target_recipients: legacy_user.username,
           }

      expect(response.status).to eq(422)
    end
  end
end

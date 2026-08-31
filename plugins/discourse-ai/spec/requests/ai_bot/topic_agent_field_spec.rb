# frozen_string_literal: true

RSpec.describe "AI agent topic custom field" do
  fab!(:current_user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:llm_model) { Fabricate(:llm_model, name: "gpt-4") }
  fab!(:agent) do
    Fabricate(
      :ai_agent,
      allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
      allow_personal_messages: true,
    )
  end

  let(:bot_user) { llm_model.reload.user }

  before do
    enable_current_plugin
    toggle_enabled_bots(bots: [llm_model])
    SiteSetting.ai_bot_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
    SiteSetting.personal_message_enabled_groups = Group::AUTO_GROUPS[:trust_level_0]
    sign_in(current_user)
  end

  def create_pm(ai_agent_id)
    post "/posts.json",
         params: {
           raw: "Hello there, this is a personal message for a bot.",
           title: "Bot personal message",
           archetype: Archetype.private_message,
           target_recipients: bot_user.username,
           topic_custom_fields: {
             ai_agent_id: ai_agent_id,
           },
         }
  end

  it "stores an agent the user is allowed to use in personal messages" do
    create_pm(agent.id)

    expect(response.status).to eq(200)
    topic = Topic.find(response.parsed_body["topic_id"])
    expect(topic.custom_fields["ai_agent_id"]).to eq(agent.id.to_s)
  end

  it "stores a built-in system agent, which has a negative id" do
    system_agent =
      AiAgent.find(DiscourseAi::Agents::Agent.system_agents[DiscourseAi::Agents::General])
    system_agent.update!(
      allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
      allow_personal_messages: true,
      enabled: true,
    )

    create_pm(system_agent.id)

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

  context "when the PM directly targets an agent's dedicated user" do
    before { agent.create_user! }

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

    it "still accepts a PM to a default LLM bot user without an agent id" do
      post "/posts.json",
           params: {
             raw: "Hello there, this is a personal message for a bot.",
             title: "Bot personal message",
             archetype: Archetype.private_message,
             target_recipients: bot_user.username,
           }

      expect(response.status).to eq(200)
    end
  end
end

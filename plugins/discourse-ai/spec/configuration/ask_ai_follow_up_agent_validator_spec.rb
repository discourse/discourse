# frozen_string_literal: true

describe DiscourseAi::Configuration::AskAiFollowUpAgentValidator do
  fab!(:valid_agent) do
    Fabricate(
      :ai_agent,
      enabled: true,
      allow_personal_messages: true,
      allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
    )
  end
  fab!(:disabled_agent) do
    Fabricate(
      :ai_agent,
      enabled: false,
      allow_personal_messages: true,
      allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
    )
  end
  fab!(:agent_without_personal_messages) do
    Fabricate(
      :ai_agent,
      enabled: true,
      allow_personal_messages: false,
      allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
    )
  end
  fab!(:agent_without_allowed_groups) do
    Fabricate(:ai_agent, enabled: true, allow_personal_messages: true, allowed_group_ids: [])
  end

  before { enable_current_plugin }

  let(:validator) { described_class.new(name: :ai_ask_ai_follow_up_agent) }

  it "accepts an enabled agent that allows personal messages for a group" do
    expect(validator.valid_value?(valid_agent.id)).to eq(true)
  end

  it "rejects a disabled agent" do
    expect(validator.valid_value?(disabled_agent.id)).to eq(false)
    expect(validator.error_message).to eq(
      I18n.t("discourse_ai.ask_ai.configuration.agent_disabled"),
    )
  end

  it "rejects an agent that does not allow personal messages" do
    expect(validator.valid_value?(agent_without_personal_messages.id)).to eq(false)
    expect(validator.error_message).to eq(
      I18n.t("discourse_ai.ask_ai.configuration.personal_messages_disabled"),
    )
  end

  it "rejects an agent without an allowed group" do
    expect(validator.valid_value?(agent_without_allowed_groups.id)).to eq(false)
    expect(validator.error_message).to eq(
      I18n.t("discourse_ai.ask_ai.configuration.allowed_groups_missing"),
    )
  end

  it "validates assignments to the follow-up agent site setting" do
    SiteSetting.ai_ask_ai_follow_up_agent = valid_agent.id

    expect(SiteSetting.ai_ask_ai_follow_up_agent).to eq(valid_agent.id.to_s)
    expect { SiteSetting.ai_ask_ai_follow_up_agent = disabled_agent.id }.to raise_error(
      Discourse::InvalidParameters,
      /must be enabled/,
    )
  end
end

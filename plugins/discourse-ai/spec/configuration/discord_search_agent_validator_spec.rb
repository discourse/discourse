# frozen_string_literal: true

RSpec.describe DiscourseAi::Configuration::DiscordSearchAgentValidator do
  fab!(:agent_without_user, :ai_agent)
  fab!(:agent_user, :user)
  fab!(:agent_with_user) { Fabricate(:ai_agent, user: agent_user) }

  before do
    enable_current_plugin
    SiteSetting.ai_discord_search_enabled = false
    SiteSetting.ai_discord_search_mode = "search"
    SiteSetting.ai_discord_search_agent = ""
  end

  it "allows disabling Discord search" do
    SiteSetting.ai_discord_search_mode = "agent"
    SiteSetting.ai_discord_search_agent = agent_without_user.id

    validator = described_class.new(name: :ai_discord_search_enabled)

    expect(validator.valid_value?("f")).to eq(true)
  end

  it "allows search mode without an associated agent user" do
    SiteSetting.ai_discord_search_enabled = true
    SiteSetting.ai_discord_search_agent = agent_without_user.id

    validator = described_class.new(name: :ai_discord_search_agent)

    expect(validator.valid_value?(agent_without_user.id)).to eq(true)
  end

  it "blocks enabling agent mode without an associated agent user" do
    SiteSetting.ai_discord_search_mode = "agent"
    SiteSetting.ai_discord_search_agent = agent_without_user.id

    validator = described_class.new(name: :ai_discord_search_enabled)

    expect(validator.valid_value?("t")).to eq(false)
    expect(validator.error_message).to eq(
      I18n.t("discourse_ai.discord.configuration.agent_user_required"),
    )
  end

  it "blocks switching to agent mode without an associated agent user" do
    SiteSetting.ai_discord_search_enabled = true
    SiteSetting.ai_discord_search_agent = agent_without_user.id

    validator = described_class.new(name: :ai_discord_search_mode)

    expect(validator.valid_value?("agent")).to eq(false)
  end

  it "blocks switching agents when the new agent has no user" do
    SiteSetting.ai_discord_search_mode = "agent"
    SiteSetting.ai_discord_search_agent = agent_with_user.id
    SiteSetting.ai_discord_search_enabled = true

    validator = described_class.new(name: :ai_discord_search_agent)

    expect(validator.valid_value?(agent_without_user.id)).to eq(false)
  end

  it "allows agent mode when the selected agent has a user" do
    SiteSetting.ai_discord_search_mode = "agent"
    SiteSetting.ai_discord_search_agent = agent_with_user.id

    validator = described_class.new(name: :ai_discord_search_enabled)

    expect(validator.valid_value?("t")).to eq(true)
  end
end

# frozen_string_literal: true

RSpec.describe "AI Bot - Mobile tab bar", mobile: true do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:claude_2) do
    Fabricate(
      :llm_model,
      provider: "anthropic",
      url: "https://api.anthropic.com/v1/messages",
      name: "claude-2",
      display_name: "Claude 2",
    )
  end
  fab!(:general_agent) do
    AiAgent
      .find(DiscourseAi::Agents::Agent.system_agents[DiscourseAi::Agents::General])
      .tap do |agent|
        agent.update!(default_llm: claude_2)
        agent.ensure_user!
      end
  end
  fab!(:bot_user) do
    enable_current_plugin
    toggle_enabled_bots(bots: [claude_2])
    SiteSetting.ai_bot_enabled = true
    general_agent.user
  end
  fab!(:pm) do
    Fabricate(
      :private_message_topic,
      title: "This is my special PM",
      user: user,
      last_posted_at: Time.zone.now,
      topic_allowed_users: [
        Fabricate.build(:topic_allowed_user, user: user),
        Fabricate.build(:topic_allowed_user, user: bot_user),
      ],
    )
  end
  fab!(:first_post) { Fabricate(:post, topic: pm, user: user, raw: "This is a reply by the user") }
  fab!(:second_post) { Fabricate(:post, topic: pm, user: bot_user, raw: "This is a bot reply") }
  fab!(:agent) do
    agent =
      AiAgent.create!(
        name: "Test Agent",
        description: "A test agent",
        allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
        enabled: true,
        system_prompt: "You are a helpful bot",
      )
    agent.create_user!
    agent.update!(default_llm_id: claude_2.id)
    agent
  end

  let(:tab_bar) { PageObjects::Components::MobileTabBar.new }
  let(:conversation_list) { ".ai-bot-mobile-conversation-list .sidebar-panel-page" }

  before do
    enable_current_plugin
    pm.custom_fields[DiscourseAi::AiBot::TOPIC_AI_BOT_PM_FIELD] = "t"
    pm.custom_fields[DiscourseAi::AiBot::TOPIC_AI_AGENT_ID_FIELD] = general_agent.id
    pm.custom_fields[DiscourseAi::AiBot::TOPIC_AI_LLM_MODEL_ID_FIELD] = claude_2.id
    pm.save_custom_fields
    toggle_enabled_bots(bots: [claude_2])
    SiteSetting.enable_mobile_tab_bar = true
    SiteSetting.sidebar_user_navigation = true
    SiteSetting.ai_bot_allowed_groups = "#{Group::AUTO_GROUPS[:trust_level_0]}"
    sign_in(user)
  end

  it "lists past conversations under the new conversation input and keeps the forum's menu" do
    visit("/latest")

    tab_bar.click_tab("ai-conversations")

    expect(page).to have_css("#ai-bot-conversations-input")
    expect(page).to have_css(
      "#{conversation_list} .sidebar-section-link",
      text: "This is my special PM",
    )

    tab_bar.open_menu

    expect(page).to have_css(
      ".sidebar-hamburger-dropdown .sidebar-section-wrapper[data-section-name='community']",
    )
  end
end

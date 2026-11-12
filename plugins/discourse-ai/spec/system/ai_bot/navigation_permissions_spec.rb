# frozen_string_literal: true

describe "AI bot navigation permissions" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:group)
  fab!(:llm_model)
  fab!(:agent) do
    Fabricate(
      :ai_agent,
      allowed_group_ids: [group.id],
      default_llm: llm_model,
      enabled: true,
      allow_personal_messages: true,
    ).tap(&:ensure_user!)
  end

  let(:navigation) { PageObjects::Components::AiBotNavigation.new }

  before do
    enable_current_plugin
    toggle_enabled_bots(bots: [llm_model])
    SiteSetting.ai_bot_allowed_groups = group.id.to_s
    SiteSetting.ai_bot_add_to_community_section = true
    SiteSetting.ai_bot_add_to_header = true
    SiteSetting.navigation_menu = "sidebar"
    group.add(user)
    sign_in(user)
  end

  it "hides the shortcuts when the bot is disabled" do
    SiteSetting.ai_bot_enabled = false
    visit "/latest"
    expect(navigation).to have_no_shortcuts
  end

  it "hides the shortcuts from users outside the bot allowed groups" do
    SiteSetting.ai_bot_allowed_groups = Group::AUTO_GROUPS[:staff].to_s
    visit "/latest"
    expect(navigation).to have_no_shortcuts
  end

  it "shows the shortcuts when only the agent default model is available" do
    SiteSetting.ai_bot_enabled_llms = ""
    visit "/latest"
    expect(navigation).to have_shortcuts
  end
end

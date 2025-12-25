# frozen_string_literal: true

RSpec.describe "AI Bot sidebar navigation" do
  fab!(:admin)
  fab!(:gpt_4) { Fabricate(:llm_model, name: "gpt-4") }
  fab!(:channel, :category_channel)

  let(:ai_pm_homepage) { PageObjects::Components::AiPmHomepage.new }
  let(:chat) { PageObjects::Components::Chat.new }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    toggle_enabled_bots(bots: [gpt_4])
    SiteSetting.navigation_menu = "sidebar"
    SiteSetting.chat_separate_sidebar_mode = "always"
    chat_system_bootstrap
    channel.add(admin)
    sign_in(admin)
  end

  it "respects sidebar panel set by destination route" do
    chat.prefers_full_page

    ai_pm_homepage.visit

    expect(page).to have_css(".sidebar-sections.ai-conversations-panel")

    find(".chat-header-icon").click

    expect(page).to have_css(".sidebar-sections.chat-panel")
  end

  it "resets to main panel when destination route has no panel" do
    ai_pm_homepage.visit

    expect(page).to have_css(".sidebar-sections.ai-conversations-panel")

    find(".sidebar-sections__back-to-forum").click

    expect(page).to have_no_css(".sidebar-sections.ai-conversations-panel")
    expect(page).to have_no_css(".sidebar-sections.chat-panel")
  end
end

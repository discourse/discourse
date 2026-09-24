# frozen_string_literal: true

RSpec.describe "AI Bot - Anonymous conversations preview" do
  let(:ai_pm_homepage) { PageObjects::Components::AiPmHomepage.new }
  let(:login_form) { PageObjects::Pages::Login.new }

  fab!(:user) do
    Fabricate(:user, username: "john", password: "supersecurepassword", refresh_auto_groups: true)
  end
  fab!(:group)
  fab!(:gpt_4) { Fabricate(:llm_model, name: "gpt-4") }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    toggle_enabled_bots(bots: [gpt_4])
    SiteSetting.ai_bot_allowed_groups = "#{group.id}|#{Group::AUTO_GROUPS[:anonymous_users]}"
    SiteSetting.default_homepage = "ai-conversations"
    SiteSetting.enable_local_logins_via_code = false
    EmailToken.confirm(Fabricate(:email_token, user: user).token)
    group.add(user)
  end

  it "keeps a question asked while logged out and restores it after logging in" do
    visit "/"

    expect(ai_pm_homepage).to have_homepage
    expect(ai_pm_homepage).to have_anonymous_card
    expect(page).to have_current_path("/")

    ai_pm_homepage.input.fill_in(with: "How do I install a theme component?")
    ai_pm_homepage.submit
    login_form.fill(username: "john", password: "supersecurepassword").click_login

    expect(ai_pm_homepage).to have_input_value("How do I install a theme component?")
  end

  it "opens login from the sidebar card" do
    visit "/"
    ai_pm_homepage.click_anonymous_card

    expect(login_form).to be_open
  end

  it "moves the card into the page while the sidebar is closed" do
    visit "/"
    expect(page).to have_css(".sidebar-wrapper .ai-bot-anonymous-card")
    expect(page).to have_no_css(".ai-bot-conversations .ai-bot-anonymous-card")

    find(".header-sidebar-toggle button").click

    expect(page).to have_no_css(".sidebar-wrapper .ai-bot-anonymous-card")
    expect(page).to have_css(".ai-bot-conversations .ai-bot-anonymous-card")
  end

  it "prompts anonymous visitors to log in when the preview is off" do
    SiteSetting.ai_bot_allowed_groups = group.id.to_s

    ai_pm_homepage.visit

    expect(login_form).to be_open
    expect(ai_pm_homepage).to have_no_homepage
  end
end

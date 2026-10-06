# frozen_string_literal: true

RSpec.describe "AI Bot - Conversations as the default homepage" do
  let(:ai_pm_homepage) { PageObjects::Components::AiPmHomepage.new }
  let(:header) { PageObjects::Pages::DiscourseAi::Header.new }
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
    SiteSetting.ai_bot_allowed_groups = group.id.to_s
    SiteSetting.ai_bot_add_to_header = true
    SiteSetting.navigation_menu = "sidebar"
    SiteSetting.top_menu = "hot|latest|new|categories"
    SiteSetting.default_homepage = "ai-conversations"
    group.add(user)
  end

  it "renders conversations at the root path and exits to the top menu homepage" do
    sign_in(user)

    visit "/"

    expect(ai_pm_homepage).to have_homepage
    expect(page).to have_current_path("/?agent=forum-helper")

    header.click_bot_button

    expect(ai_pm_homepage).to have_no_homepage
    expect(page).to have_current_path("/hot")
  end

  it "asks anonymous visitors to log in when login is required, then shows conversations" do
    SiteSetting.login_required = true
    SiteSetting.enable_local_logins_via_code = false
    EmailToken.confirm(Fabricate(:email_token, user: user).token)

    visit "/"

    expect(page).to have_css(".login-welcome")
    expect(ai_pm_homepage).to have_no_homepage

    find(".login-welcome .login-button").click
    login_form.fill(username: "john", password: "supersecurepassword").click_login

    expect(ai_pm_homepage).to have_homepage
    expect(page).to have_current_path("/?agent=forum-helper")
  end
end

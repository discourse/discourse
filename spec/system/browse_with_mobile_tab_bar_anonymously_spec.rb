# frozen_string_literal: true

RSpec.describe "Browse with mobile tab bar anonymously", mobile: true do
  fab!(:topic) { Fabricate(:post).topic }

  let(:tab_bar) { PageObjects::Components::MobileTabBar.new }
  let(:login_page) { PageObjects::Pages::Login.new }
  let(:signup_page) { PageObjects::Pages::Signup.new }

  before do
    SiteSetting.mobile_footer_navigation = true
    SiteSetting.chat_enabled = false if SiteSetting.respond_to?(:chat_enabled)
  end

  it "offers the topics with their views, and logging in where creating would be" do
    visit("/latest")

    expect(tab_bar).to have_tabs("main")
    expect(page).to have_css(".mobile-tab-bar__views #navigation-bar")
    expect(page).to have_no_css(".d-header .login-button")
    expect(tab_bar).to have_named_log_in

    tab_bar.click_log_in

    expect(page).to have_css(".login-fullpage, .d-modal.login-modal, #login-form")
  end

  it "lets visitors sign up through the login page" do
    visit("/latest")

    expect(tab_bar).to have_named_log_in
    expect(tab_bar).to have_no_sign_up

    tab_bar.click_log_in
    login_page.open_signup

    expect(signup_page).to be_open
  end

  it "leaves visitors to a private site with only the login page" do
    SiteSetting.login_required = true

    visit("/")

    expect(page).to have_css(".login-welcome, .login-required")
    expect(tab_bar).to be_hidden
  end
end

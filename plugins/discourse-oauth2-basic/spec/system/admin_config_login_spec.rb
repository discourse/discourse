# frozen_string_literal: true

describe "Admin Config Login and Authentication OAuth2 tab", type: :system do
  fab!(:current_user, :admin)

  let(:admin_login_page) { PageObjects::Pages::AdminLoginAndAuthentication.new }
  let(:search_modal) { PageObjects::Modals::AdminSearch.new }
  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }

  before { sign_in(current_user) }

  it "shows the login and authentication tabs and allows navigating to the oauth2 tab" do
    admin_login_page.visit

    admin_login_page.click_tab("discourseconnect")
    expect(admin_login_page).to have_setting("enable_discourse_connect")

    admin_login_page.click_tab("oauth2")
    expect(admin_login_page).to have_setting("oauth2_enabled")
  end

  it "finds the tab via admin search" do
    visit "/admin"
    sidebar.click_search_input
    search_modal.search("oauth2")
    search_modal.find_result("page", 0).click

    expect(page).to have_current_path("/admin/config/login-and-authentication/oauth2")
  end
end

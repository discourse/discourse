# frozen_string_literal: true

describe "Admin Config Login and Authentication OIDC tab", type: :system do
  fab!(:current_user, :admin)

  let(:admin_login_page) { PageObjects::Pages::AdminLoginAndAuthentication.new }
  let(:search_modal) { PageObjects::Modals::AdminSearch.new }
  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }

  before { sign_in(current_user) }

  it "shows the login and authentication tabs and allows navigating to the oidc tab" do
    admin_login_page.visit

    admin_login_page.click_tab("discourseconnect")
    expect(admin_login_page).to have_setting("enable_discourse_connect")

    admin_login_page.click_tab("oidc")
    expect(admin_login_page).to have_setting("openid_connect_enabled")
  end

  it "finds the tab via admin search" do
    visit "/admin"
    sidebar.click_search_input
    search_modal.search("oidc")
    search_modal.find_result("page", 0).click

    expect(page).to have_current_path("/admin/config/login-and-authentication/oidc")
  end
end

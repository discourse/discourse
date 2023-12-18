# frozen_string_literal: true

describe "Admin Revamp | Sidebar Navigation", type: :system do
  fab!(:admin)
  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }

  before do
    SiteSetting.enable_admin_sidebar_navigation = true
    sign_in(admin)
  end

  it "shows the sidebar when navigating to an admin route and hides it when leaving" do
    visit("/latest")
    sidebar.click_link_in_section("community", "admin")
    expect(page).to have_current_path("/admin")
    expect(sidebar).to be_visible
    expect(page).to have_no_css(".admin-main-nav")
    sidebar.click_link_in_section("admin-nav-section-root", "back_to_forum")
    expect(page).to have_current_path("/latest")
    expect(sidebar).to have_no_section("admin-nav-section-root")
  end

  it "does not show the admin sidebar if the setting is disabled" do
    SiteSetting.enable_admin_sidebar_navigation = false
    visit("/latest")
    sidebar.click_link_in_section("community", "admin")
    expect(page).to have_current_path("/admin")
    expect(sidebar).to have_no_section("admin-nav-section-root")
  end
end

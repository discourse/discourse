# frozen_string_literal: true

describe "Admin Revamp | Sidebar Navigation", type: :system do
  fab!(:admin)

  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }
  let(:sidebar_dropdown) { PageObjects::Components::SidebarHeaderDropdown.new }

  before do
    SiteSetting.admin_sidebar_enabled_groups = Group::AUTO_GROUPS[:admins]
    sign_in(admin)
  end

  it "shows the sidebar when navigating to an admin route and hides it when leaving" do
    visit("/latest")
    expect(sidebar).to have_section("community")
    sidebar.click_link_in_section("community", "admin")
    expect(page).to have_current_path("/admin")
    expect(sidebar).to be_visible
    expect(sidebar).to have_no_section("community")
    expect(page).to have_no_css(".admin-main-nav")
    sidebar.click_link_in_section("admin-nav-section-root", "back_to_forum")
    expect(page).to have_current_path("/latest")
    expect(sidebar).to have_no_section("admin-nav-section-root")
  end

  it "respects the user homepage preference for the Back to Forum link" do
    admin.user_option.update!(
      homepage_id: UserOption::HOMEPAGES.find { |id, value| value == "categories" }.first,
    )
    visit("/admin")
    expect(page).to have_link("Back to Forum", href: "/categories")
  end

  context "when on mobile" do
    it "shows the admin sidebar links in the header-dropdown when navigating to an admin route and hides them when leaving",
       mobile: true do
      visit("/latest")
      sidebar_dropdown.click
      expect(sidebar).to have_section("community")
      sidebar.click_link_in_section("community", "admin")
      expect(page).to have_current_path("/admin")
      sidebar_dropdown.click
      expect(sidebar).to have_no_section("community")
      expect(page).to have_no_css(".admin-main-nav")
      sidebar.click_link_in_section("admin-nav-section-root", "back_to_forum")
      expect(page).to have_current_path("/latest")
      sidebar_dropdown.click
      expect(sidebar).to have_no_section("admin-nav-section-root")
    end
  end

  context "when the setting is disabled" do
    before { SiteSetting.admin_sidebar_enabled_groups = "" }

    it "does not show the admin sidebar" do
      visit("/latest")
      sidebar.click_link_in_section("community", "admin")
      expect(page).to have_current_path("/admin")
      expect(sidebar).to have_no_section("admin-nav-section-root")
    end
  end
end

# frozen_string_literal: true

describe "Admin Revamp | Sidebar Naviagion", type: :system do
  fab!(:admin) { Fabricate(:admin) }
  let(:sidebar_page) { PageObjects::Components::NavigationMenu::Sidebar.new }

  before do
    SiteSetting.enable_experimental_admin_ui_groups = Group::AUTO_GROUPS[:staff]
    SidebarSection.find_by(section_type: "community").reset_community!
    sign_in(admin)
  end

  it "navigates to the admin revamp from the sidebar" do
    visit("/latest")
    sidebar_page.click_section_link("Admin Revamp")
    expect(page).to have_content("Lobby")
    expect(page).to have_content("Legacy Admin")
  end
end

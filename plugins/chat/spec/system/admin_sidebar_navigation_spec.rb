# frozen_string_literal: true

describe "Admin Revamp | Sidebar Navigation | Plugin Links", type: :system do
  fab!(:admin)
  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }

  before do
    chat_system_bootstrap
    SiteSetting.admin_sidebar_enabled_groups = Group::AUTO_GROUPS[:admins]
    sign_in(admin)
  end

  it "shows links to enabled plugin admin routes" do
    visit("/admin")
    expect(sidebar).to have_section_link("Chat", href: "/admin/plugins/chat")
  end
end

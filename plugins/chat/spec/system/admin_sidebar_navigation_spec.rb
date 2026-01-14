# frozen_string_literal: true

describe "Admin Revamp | Sidebar Navigation | Plugin Links", type: :system do
  fab!(:admin)
  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }
  let(:chat_page) { PageObjects::Pages::Chat.new }

  before do
    chat_system_bootstrap
    sign_in(admin)
  end

  it "shows links to enabled plugin admin routes" do
    visit("/admin")
    sidebar.toggle_all_sections
    expect(sidebar).to have_section_link("Chat", href: "/admin/plugins/chat")
  end

  it "does not duplicate links to enabled plugin admin routes when showing and hiding sidebar" do
    visit("/admin")
    sidebar.toggle_all_sections
    expect(sidebar).to have_section_link("Chat", href: "/admin/plugins/chat", count: 1)
    find(".header-sidebar-toggle").click
    find(".header-sidebar-toggle").click
    expect(sidebar).to have_section_link("Chat", href: "/admin/plugins/chat", count: 1)
  end

  it "does not show plugin links in the admin sidebar in safe mode" do
    visit("/safe-mode")
    find("#btn-enter-safe-mode").click
    expect(sidebar).to have_section_link("Admin", href: "/admin")
    sidebar.click_link_in_section("community", "admin")
    expect(sidebar).to have_no_section_link("Chat", href: "/admin/plugins/chat")
  end

  describe "admin sidebar respects separated and combined sidebar modes" do
    it "reverts to always (separated) mode after entering and leaving admin section" do
      admin.user_option.update!(
        chat_separate_sidebar_mode: UserOption.chat_separate_sidebar_modes[:always],
      )
      visit("/")
      expect(sidebar).to have_switch_button("chat")
      sidebar.click_link_in_section("community", "admin")
      expect(sidebar).to have_no_switch_button("chat")
      click_logo
      expect(sidebar).to have_switch_button("chat")
    end

    it "reverts to the never (combined) mode after entering and leaving admin section" do
      admin.user_option.update!(
        chat_separate_sidebar_mode: UserOption.chat_separate_sidebar_modes[:never],
      )
      visit("/")
      expect(sidebar).to have_section("chat-channels")
      expect(sidebar).to have_no_switch_button("chat")
      sidebar.click_link_in_section("community", "admin")
      expect(sidebar).to have_no_section("chat-channels")
      click_logo
      expect(sidebar).to have_section("chat-channels")
    end

    it "keeps the admin sidebar open instead of switching to the main panel when toggling the drawer" do
      membership =
        Fabricate(
          :user_chat_channel_membership,
          user: admin,
          chat_channel: Fabricate(:chat_channel),
        )
      admin.upsert_custom_fields(::Chat::LAST_CHAT_CHANNEL_ID => membership.chat_channel.id)
      chat_page.prefers_full_page
      visit("/admin")
      expect(sidebar).to have_section("admin-root")
      chat_page.open_from_header
      expect(sidebar).to have_no_section("admin-root")
      chat_page.minimize_full_page
      expect(chat_page).to have_drawer
      expect(sidebar).to have_section("admin-root")
    end
  end
end

# frozen_string_literal: true

RSpec.describe "Separate sidebar mode", type: :system do
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:sidebar_page) { PageObjects::Pages::Sidebar.new }
  let(:sidebar_component) { PageObjects::Components::NavigationMenu::Sidebar.new }
  let(:chat_drawer_page) { PageObjects::Pages::ChatDrawer.new }
  let(:header_component) { PageObjects::Components::Chat::Header.new }

  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:chat_channel) }

  before do
    SiteSetting.navigation_menu = "sidebar"
    channel_1.add(current_user)
    chat_system_bootstrap
    sign_in(current_user)
  end

  describe "when separate sidebar mode is not set" do
    before do
      SiteSetting.chat_separate_sidebar_mode = "always"
      chat_page.prefers_full_page
    end

    it "uses the site setting" do
      visit("/")

      expect(sidebar_component).to have_switch_button("chat")
      expect(header_component).to have_open_chat_button
      expect(sidebar_component).to have_no_section("chat-channels")
      expect(sidebar_component).to have_section("Categories")

      chat_page.open_from_header

      expect(sidebar_component).to have_switch_button("main")
      expect(header_component).to have_open_forum_button
      expect(sidebar_component).to have_section("chat-channels")
      expect(sidebar_component).to have_no_section("Categories")

      find("#site-logo").click

      expect(sidebar_component).to have_switch_button("chat")
      expect(header_component).to have_open_chat_button
      expect(sidebar_component).to have_no_section("chat-channels")
      expect(sidebar_component).to have_section("Categories")
    end
  end

  describe "when separate sidebar mode is never" do
    before do
      current_user.user_option.update!(
        chat_separate_sidebar_mode: UserOption.chat_separate_sidebar_modes[:never],
      )
    end

    context "with drawer" do
      before { chat_page.prefers_drawer }

      it "has the expected behavior" do
        visit("/")

        expect(sidebar_component).to have_no_switch_button
        expect(header_component).to have_open_chat_button
        expect(sidebar_component).to have_section("Categories")
        expect(sidebar_component).to have_section("chat-channels")

        sidebar_page.open_channel(channel_1)

        expect(sidebar_component).to have_no_switch_button
        expect(header_component).to have_open_chat_button
        expect(sidebar_component).to have_section("Categories")
        expect(sidebar_component).to have_section("chat-channels")

        chat_drawer_page.close

        expect(sidebar_component).to have_no_switch_button
        expect(header_component).to have_open_chat_button
        expect(sidebar_component).to have_section("Categories")
        expect(sidebar_component).to have_section("chat-channels")
      end
    end

    context "with full page" do
      before { chat_page.prefers_full_page }

      it "has the expected behavior" do
        visit("/")

        expect(sidebar_component).to have_no_switch_button
        expect(header_component).to have_open_chat_button
        expect(sidebar_component).to have_section("Categories")
        expect(sidebar_component).to have_section("chat-channels")

        sidebar_page.open_channel(channel_1)

        expect(sidebar_component).to have_no_switch_button
        expect(header_component).to have_open_chat_button
        expect(sidebar_component).to have_section("Categories")
        expect(sidebar_component).to have_section("chat-channels")

        find("#site-logo").click

        expect(sidebar_component).to have_no_switch_button
        expect(header_component).to have_open_chat_button
        expect(sidebar_component).to have_section("Categories")
        expect(sidebar_component).to have_section("chat-channels")
      end
    end
  end

  describe "when separate sidebar mode is always" do
    before do
      current_user.user_option.update(
        chat_separate_sidebar_mode: UserOption.chat_separate_sidebar_modes[:always],
      )
    end

    context "with drawer" do
      before { chat_page.prefers_drawer }

      it "has the expected behavior" do
        visit("/")

        expect(sidebar_component).to have_switch_button("chat")
        expect(header_component).to have_open_chat_button
        expect(sidebar_component).to have_no_section("chat-channels")

        chat_page.open_from_header

        expect(sidebar_component).to have_no_switch_button
        expect(header_component).to have_open_chat_button
        expect(sidebar_component).to have_no_section("chat-channels")

        chat_drawer_page.close

        expect(sidebar_component).to have_switch_button("chat")
        expect(header_component).to have_open_chat_button
        expect(sidebar_component).to have_no_section("chat-channels")
      end
    end

    context "with full page" do
      before { chat_page.prefers_full_page }

      it "has the expected behavior" do
        visit("/")

        expect(sidebar_component).to have_switch_button("chat")
        expect(header_component).to have_open_chat_button
        expect(sidebar_component).to have_no_section("chat-channels")
        expect(sidebar_component).to have_section("Categories")

        chat_page.open_from_header

        expect(sidebar_component).to have_switch_button("main")
        expect(header_component).to have_open_forum_button
        expect(sidebar_component).to have_section("chat-channels")
        expect(sidebar_component).to have_no_section("Categories")

        find("#site-logo").click

        expect(sidebar_component).to have_switch_button("chat")
        expect(header_component).to have_open_chat_button
        expect(sidebar_component).to have_no_section("chat-channels")
        expect(sidebar_component).to have_section("Categories")
      end
    end
  end

  describe "when separate sidebar mode is fullscreen" do
    before do
      current_user.user_option.update(
        chat_separate_sidebar_mode: UserOption.chat_separate_sidebar_modes[:fullscreen],
      )
    end

    context "with drawer" do
      before { chat_page.prefers_drawer }

      it "has the expected behavior" do
        visit("/")

        expect(sidebar_component).to have_switch_button
        expect(header_component).to have_open_chat_button
        expect(sidebar_component).to have_section("Categories")
        expect(sidebar_component).to have_section("chat-channels")

        sidebar_page.open_channel(channel_1)

        expect(sidebar_component).to have_no_switch_button
        expect(header_component).to have_open_chat_button
        expect(sidebar_component).to have_section("Categories")
        expect(sidebar_component).to have_section("chat-channels")

        chat_drawer_page.close

        expect(sidebar_component).to have_switch_button
        expect(header_component).to have_open_chat_button
        expect(sidebar_component).to have_section("Categories")
        expect(sidebar_component).to have_section("chat-channels")
      end
    end

    context "with full page" do
      before { chat_page.prefers_full_page }

      it "has the expected behavior" do
        visit("/")

        expect(sidebar_component).to have_switch_button("chat")
        expect(header_component).to have_open_chat_button
        expect(sidebar_component).to have_section("chat-channels")
        expect(sidebar_component).to have_section("Categories")

        sidebar_page.open_channel(channel_1)

        expect(sidebar_component).to have_switch_button("main")
        expect(header_component).to have_open_forum_button
        expect(sidebar_component).to have_section("chat-channels")
        expect(sidebar_component).to have_no_section("Categories")

        find("#site-logo").click

        expect(sidebar_component).to have_switch_button("chat")
        expect(header_component).to have_open_chat_button
        expect(sidebar_component).to have_section("chat-channels")
        expect(sidebar_component).to have_section("Categories")
      end
    end
  end
end

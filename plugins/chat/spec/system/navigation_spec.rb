# frozen_string_literal: true

RSpec.describe "Navigation", type: :system do
  fab!(:category)
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:current_user) { Fabricate(:admin) }
  fab!(:category_channel)
  fab!(:category_channel_2) { Fabricate(:category_channel) }
  fab!(:message) { Fabricate(:chat_message, chat_channel: category_channel) }
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:thread_page) { PageObjects::Pages::ChatThread.new }
  let(:thread_list_page) { PageObjects::Components::Chat::ThreadList.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:side_panel_page) { PageObjects::Pages::ChatSidePanel.new }
  let(:sidebar_page) { PageObjects::Pages::Sidebar.new }
  let(:sidebar_component) { PageObjects::Components::NavigationMenu::Sidebar.new }
  let(:chat_drawer_page) { PageObjects::Pages::ChatDrawer.new }

  before do
    current_user.upsert_custom_fields(::Chat::LAST_CHAT_CHANNEL_ID => category_channel.id)
    chat_system_bootstrap(current_user, [category_channel, category_channel_2])
    current_user.user_option.update(
      chat_separate_sidebar_mode: UserOption.chat_separate_sidebar_modes[:never],
    )
    sign_in(current_user)
  end

  context "when clicking chat icon and drawer is viewing channel" do
    it "navigates to index" do
      visit("/")

      chat_page.open_from_header
      chat_drawer_page.open_channel(category_channel_2)
      chat_page.open_from_header

      expect(page).to have_content(I18n.t("js.chat.direct_messages.title"))
    end
  end

  context "when clicking chat icon on mobile and is viewing channel" do
    it "navigates to channels tab", mobile: true do
      chat_page.visit_channel(category_channel_2)
      chat_page.open_from_header

      expect(page).to have_current_path("/chat/channels")
    end
  end

  context "when clicking chat icon on mobile" do
    it "has the chat title with link to chat index", mobile: true do
      visit("/")
      chat_page.open_from_header

      expect(page).to have_title(I18n.t("js.chat.heading"))
      expect(page).to have_css("a.c-heading[href='#{chat_path}']")
    end

    it "has the back to forum link with last visited url", mobile: true do
      visit("/")
      click_link(topic.title)

      expect(page).to have_css(".fancy-title")

      chat_page.open_from_header

      expect(page).to have_title(I18n.t("js.chat.heading"))
      expect(page).to have_css(".back-to-forum[href='#{topic.relative_url}']")
    end

    it "hides the search icon and hamburger icon", mobile: true do
      visit("/")
      chat_page.open_from_header

      expect(page).to have_no_css(".search-dropdown")
      expect(page).to have_no_css(".hamburger-dropdown")
    end
  end

  context "when visiting /chat" do
    it "opens full page" do
      chat_page.open

      expect(page).to have_current_path(
        chat.channel_path(category_channel.slug, category_channel.id),
      )
    end
  end

  context "when visiting mobile only routes on desktop" do
    it "redirects /chat/channels to browse" do
      visit("/chat/channels")

      expect(page).to have_current_path(
        chat.channel_path(category_channel.slug, category_channel.id),
      )
    end
  end

  context "when opening chat" do
    it "opens the drawer by default" do
      visit("/")
      chat_page.open_from_header

      expect(page).to have_css(".chat-drawer.is-expanded")
    end
  end

  context "when opening chat with full page as preferred mode" do
    it "opens the full page" do
      visit("/")
      chat_page.open_from_header
      chat_drawer_page.maximize

      expect(page).to have_current_path(
        chat.channel_path(category_channel.slug, category_channel.id),
      )

      visit("/")
      chat_page.open_from_header

      expect(page).to have_current_path(
        chat.channel_path(category_channel.slug, category_channel.id),
      )
    end
  end

  context "when opening chat with drawer as preferred mode" do
    it "opens the full page" do
      chat_page.open
      chat_page.minimize_full_page

      expect(page).to have_css(".chat-drawer.is-expanded")

      visit("/")
      chat_page.open_from_header

      expect(page).to have_css(".chat-drawer.is-expanded")
    end
  end

  context "when opening channel settings from thread" do
    fab!(:thread) { Fabricate(:chat_thread, channel: category_channel, use_service: true) }

    before do
      category_channel.update!(threading_enabled: true)
      Fabricate(:chat_message, thread: thread, use_service: true)
      thread.add(current_user)
    end

    it "correctly closes the side panel" do
      chat_page.visit_thread(thread)

      find(".c-navbar__channel-title").click

      expect(page).to have_no_selector(".main-chat-outlet.has-side-panel-expanded")
    end
  end

  context "when collapsing full page with no previous state" do
    it "redirects to home page" do
      chat_page.open
      chat_page.minimize_full_page

      expect(page).to have_current_path("/latest")
    end
  end

  context "when collapsing full page with previous state" do
    it "redirects to previous state" do
      visit("/t/-/#{topic.id}")
      chat_page.open_from_header
      chat_drawer_page.maximize
      chat_page.minimize_full_page

      expect(page).to have_current_path("/t/#{topic.slug}/#{topic.id}")
      expect(page).to have_css(".chat-message-container[data-id='#{message.id}']")
    end
  end

  context "when opening a thread" do
    fab!(:thread) { Fabricate(:chat_thread, channel: category_channel, use_service: true) }

    before do
      category_channel.update!(threading_enabled: true)
      Fabricate(:chat_message, thread: thread, use_service: true)
      thread.add(current_user)
    end

    context "when opening a thread from the thread list" do
      xit "goes back to the thread list when clicking the back button" do
        skip_on_ci!

        visit("/chat")
        chat_page.visit_channel(category_channel)
        channel_page.open_thread_list
        expect(thread_list_page).to have_loaded
        thread_list_page.open_thread(thread)
        expect(side_panel_page).to have_open_thread(thread)
        expect(thread_page).to have_back_link_to_thread_list(category_channel)
        thread_page.back
        expect(page).to have_current_path("#{category_channel.relative_url}/t")
        expect(thread_list_page).to have_loaded
      end

      context "for mobile" do
        it "goes back to the thread list when clicking the back button", mobile: true do
          skip_on_ci!

          visit("/chat")
          chat_page.visit_channel(category_channel)
          channel_page.open_thread_list
          expect(thread_list_page).to have_loaded
          thread_list_page.open_thread(thread)
          expect(side_panel_page).to have_open_thread(thread)
          expect(thread_page).to have_back_link_to_thread_list(category_channel)
          thread_page.back
          expect(page).to have_current_path("#{category_channel.relative_url}/t")
          expect(thread_list_page).to have_loaded
        end

        context "when there are unread threads" do
          fab!(:thread_2) { Fabricate(:chat_thread, channel: category_channel, use_service: true) }

          before { Fabricate(:chat_message, thread: thread_2, use_service: true) }

          it "goes back to the thread list when clicking the back button", mobile: true do
            skip_on_ci!

            chat_page.visit_channel(category_channel)
            channel_page.message_thread_indicator(thread.original_message).click
            thread_page.send_message
            thread_page.back
            channel_page.message_thread_indicator(thread_2.original_message).click
            Fabricate(:chat_message, thread: thread, use_service: true)

            expect(thread_page).to have_unread_list_indicator(count: 1)
            expect(thread_page).to have_back_link_to_thread_list(category_channel)
            thread_page.back
            expect(page).to have_current_path("#{category_channel.relative_url}/t")
          end
        end
      end
    end

    context "when opening a thread from indicator" do
      it "goes back to the thread list when clicking the back button" do
        skip_on_ci!

        visit("/chat")
        chat_page.visit_channel(category_channel)
        channel_page.message_thread_indicator(thread.original_message).click
        expect(side_panel_page).to have_open_thread(thread)
        expect(thread_page).to have_back_link_to_thread_list(category_channel)
        thread_page.back
        expect(page).to have_current_path("#{category_channel.relative_url}/t")
        expect(thread_list_page).to have_loaded
      end

      context "for mobile" do
        it "closes the thread and goes back to the channel when clicking the back button",
           mobile: true do
          skip_on_ci!

          visit("/chat")
          chat_page.visit_channel(category_channel)
          channel_page.message_thread_indicator(thread.original_message).click
          expect(side_panel_page).to have_open_thread(thread)
          expect(thread_page).to have_back_link_to_channel(category_channel)
          thread_page.back
          expect(page).to have_current_path("#{category_channel.relative_url}")
          expect(side_panel_page).to be_closed
        end
      end
    end
  end

  context "when public channels are disabled" do
    before { SiteSetting.enable_public_channels = false }

    it "only show dms in drawer" do
      visit("/")
      chat_page.open_from_header

      expect(page).to have_css(".direct-message-channels.center-empty-channels-list")
      expect(chat_page).to have_no_messages
    end

    it "only show dms in desktop" do
      visit("/")
      chat_page.prefers_full_page
      chat_page.open_from_header

      expect(chat_page).to have_no_messages
      expect(page).to have_css(".c-routes.--direct-messages")
    end
  end

  context "when sidebar is configured as the navigation menu" do
    before { SiteSetting.navigation_menu = "sidebar" }

    context "when opening channel from sidebar with drawer preferred" do
      it "opens channel in drawer" do
        visit("/t/-/#{topic.id}")
        chat_page.open_from_header
        chat_drawer_page.close
        sidebar_component.click_link(category_channel.name)

        expect(page).to have_css(".chat-message-container[data-id='#{message.id}']")
      end
    end

    context "when opening channel from sidebar with full page preferred" do
      it "opens channel in full page" do
        visit("/")
        chat_page.open_from_header
        chat_drawer_page.maximize
        visit("/")
        sidebar_component.click_link(category_channel.name)

        expect(page).to have_current_path(
          chat.channel_path(category_channel.slug, category_channel.id),
        )
      end
    end

    context "when starting draft from sidebar with full page preferred" do
      it "opens draft in full page" do
        visit("/")
        chat_page.open_from_header
        chat_drawer_page.maximize
        visit("/")
        chat_page.open_new_message

        expect(chat_page.message_creator).to be_opened
      end
    end

    context "when opening browse page from sidebar in drawer mode" do
      it "opens browser page in full page" do
        visit("/")
        chat_page.open_from_header
        sidebar_page.open_browse

        expect(chat_drawer_page.browse).to have_channel(name: category_channel.name)
      end
    end

    context "when re-opening drawer after navigating to a channel" do
      it "opens drawer on correct channel" do
        visit("/")
        chat_page.open_from_header
        chat_drawer_page.open_channel(category_channel_2)
        chat_drawer_page.back
        chat_drawer_page.close
        chat_page.open_from_header

        expect(page).to have_current_path("/")
        expect(page).to have_css(".chat-drawer.is-expanded")
        expect(page).to have_content(category_channel_2.title)
      end
    end

    context "when re-opening full page chat after navigating to a channel" do
      it "opens full page chat on correct channel" do
        chat_channel_path = chat.channel_path(category_channel_2.slug, category_channel_2.id)

        visit("/")
        chat_page.open_from_header
        chat_drawer_page.maximize
        sidebar_page.open_channel(category_channel_2)
        click_logo

        expect(chat_page).to have_header_href(chat_channel_path)

        chat_page.open_from_header

        expect(page).to have_current_path(chat_channel_path)
        expect(page).to have_content(category_channel_2.title)
      end
    end

    context "when opening a channel in full page" do
      fab!(:other_user) { Fabricate(:user) }
      fab!(:dm_channel) { Fabricate(:direct_message_channel, users: [current_user, other_user]) }

      it "activates the channel in the sidebar" do
        visit("/chat/c/#{category_channel.slug}/#{category_channel.id}")

        expect(sidebar_component).to have_section_link(category_channel.name, active: true)
      end

      it "does not have multiple channels marked active in the sidebar" do
        chat_page.visit_channel(dm_channel)

        expect(sidebar_component).to have_section_link(other_user.username, active: true)

        sidebar_component.click_section_link(category_channel.name)

        expect(sidebar_component).to have_section_link(category_channel.name, active: true)
        expect(sidebar_component).to have_one_active_section_link
      end
    end

    context "when going back to channel from channel settings in full page" do
      it "activates the channel in the sidebar" do
        visit("/chat/c/#{category_channel.slug}/#{category_channel.id}/info/settings")
        find(".c-navbar__back-button").click
        expect(page).to have_content(message.message)
      end
    end

    context "when clicking logo from a channel in full page" do
      it "deactivates the channel in the sidebar" do
        visit("/chat/c/#{category_channel.slug}/#{category_channel.id}")
        click_logo

        expect(sidebar_component).to have_no_section_link(category_channel.name, active: true)
      end
    end

    context "when opening a channel in drawer" do
      it "activates the channel in the sidebar" do
        visit("/")
        chat_page.open_from_header
        sidebar_component.click_section_link(category_channel.name)

        expect(sidebar_component).to have_section_link(category_channel.name, active: true)
      end
    end

    context "when closing drawer in a channel" do
      it "deactivates the channel in the sidebar" do
        visit("/")
        chat_page.open_from_header

        sidebar_component.click_section_link(category_channel.name)
        chat_drawer_page.close

        expect(sidebar_component).to have_no_section_link(category_channel.name, active: true)
      end
    end

    context "when exiting a thread for homepage" do
      fab!(:thread) { Fabricate(:chat_thread, channel: category_channel) }

      before do
        current_user.user_option.update(
          chat_separate_sidebar_mode: UserOption.chat_separate_sidebar_modes[:always],
        )
        chat_page.prefers_full_page
        category_channel.update!(threading_enabled: true)
        thread.add(current_user)
      end

      it "correctly shows the thread panel" do
        chat_page.visit_thread(thread)

        expect(side_panel_page).to have_open_thread(thread)

        click_logo
        sidebar_component.switch_to_chat

        expect(side_panel_page).to have_open_thread(thread)
      end
    end
  end
end

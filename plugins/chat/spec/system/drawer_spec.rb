# frozen_string_literal: true

RSpec.describe "Drawer" do
  fab!(:current_user, :user)
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:drawer_page) { PageObjects::Pages::ChatDrawer.new }

  before do
    chat_system_bootstrap
    sign_in(current_user)
    chat_page.prefers_drawer
  end

  it "opens the channels list with a footer and updates the layout when maximized" do
    visit("/")

    chat_page.open_from_header
    expect(page).to have_css(
      "body.has-drawer-chat.has-chat.chat-drawer-active.chat-drawer-expanded",
    )
    expect(page).to have_css("html.has-drawer-chat.has-chat")
    expect(page).to have_no_css("body.has-full-page-chat")
    expect(drawer_page).to have_open_channels
    expect(page).to have_css(".chat-drawer .c-footer")
    expect(page).to have_css(".chat-drawer .c-footer__item", count: 3)

    drawer_page.maximize
    expect(page).to have_css("body.has-chat.has-full-page-chat")
    expect(page).to have_css("html.has-chat.has-full-page-chat")
    expect(page).to have_no_css("body.has-drawer-chat")
    expect(page).to have_no_css("html.has-drawer-chat")
  end

  it "respects drawer preference after page refresh" do
    visit("/")
    chat_page.open_from_header
    expect(page).to have_css("body.has-drawer-chat")

    drawer_page.close
    expect(page).to have_no_css("body.chat-drawer-active")

    refresh

    chat_page.open_from_header
    expect(page).to have_css("body.has-drawer-chat")
    expect(page).to have_no_css("body.has-full-page-chat")
  end

  context "when on channel" do
    fab!(:channel, :chat_channel)
    fab!(:membership) do
      Fabricate(:user_chat_channel_membership, user: current_user, chat_channel: channel)
    end

    context "when clicking channel title" do
      before do
        visit("/")
        chat_page.open_from_header
        drawer_page.open_channel(channel)
        page.find(".c-navbar__channel-title").click
      end

      it "opens preferences with a back button and working settings and members tabs" do
        expect(drawer_page).to have_channel_preferences
        expect(drawer_page).to have_css(".c-channel-info__nav li a", text: "Settings")
        expect(drawer_page).to have_css(".c-channel-info__nav li a", text: "Members")
        expect(drawer_page).to have_css(".c-navbar__back-button")

        page.find(".c-channel-info__nav li a", text: "Members").click
        expect(drawer_page).to have_channel_members

        page.find(".c-channel-info__nav li a", text: "Settings").click
        expect(drawer_page).to have_channel_settings
      end
    end
  end

  context "when opening" do
    it "uses stored size" do
      # Sign-in has already loaded a same-origin document, without booting chat.
      page.execute_script "window.localStorage.setItem('discourse_chat_drawer_size_width','500');"
      page.execute_script "window.localStorage.setItem('discourse_chat_drawer_size_height','500');"

      visit("/")

      chat_page.open_from_header

      chat_drawer = page.find(".chat-drawer")
      expect(chat_drawer).to have_computed_style(width: "500px")
      expect(chat_drawer).to have_computed_style(height: "500px")
    end

    it "uses the default size, collapses from the header, and clears its active state on close" do
      visit("/")
      chat_page.open_from_header

      chat_drawer = page.find(".chat-drawer.is-expanded")
      expect(chat_drawer).to have_computed_style(width: "400px")
      expect(chat_drawer).to have_computed_style(height: "530px")
      expect(page).to have_css("body.chat-drawer-active.chat-drawer-expanded")

      chat_drawer.find(".c-navbar").click
      expect(page).to have_css(".chat-drawer:not(.is-expanded)")
      expect(page).to have_no_css("body.chat-drawer-expanded")

      drawer_page.expand
      chat_drawer = page.find(".chat-drawer.is-expanded")
      expect(chat_drawer).to have_computed_style(width: "400px")
      expect(chat_drawer).to have_computed_style(height: "530px")
      expect(page).to have_css("body.chat-drawer-active.chat-drawer-expanded")

      drawer_page.close
      expect(page).to have_no_css("body.chat-drawer-active")
    end
  end

  context "when closing the drawer" do
    fab!(:channel_1, :chat_channel)
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }

    fab!(:membership) { channel_1.add(current_user) }

    it "resets the active message" do
      visit("/")
      chat_page.open_from_header
      drawer_page.open_channel(channel_1)
      channel_page.hover_message(message_1)

      expect(page).to have_css(".chat-message-actions-container", visible: :all)

      drawer_page.close

      expect(page).to have_no_css(".chat-message-actions-container")
    end
  end

  context "when the drawer is collapsed" do
    fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }
    fab!(:membership) do
      Fabricate(:user_chat_channel_membership, user: current_user, chat_channel: channel)
    end

    before { SiteSetting.chat_search_enabled = true }

    it "hides unusable navbar controls when collapsed and can expand by keyboard or click" do
      drawer_page.visit_channel(channel)

      expect(page).to have_selector(".c-navbar__star-channel-button")
      expect(page).to have_selector(".c-navbar__filter")
      expect(page).to have_selector(".c-navbar__threads-list-button")

      drawer_page.collapse

      expect(page).to have_selector(".chat-drawer:not(.is-expanded)")
      expect(page).to have_no_selector(".c-navbar__star-channel-button")
      expect(page).to have_no_selector(".c-navbar__filter")
      expect(page).to have_no_selector(".c-navbar__threads-list-button")
      expect(page).to have_selector(".c-navbar__close-drawer-button")

      expect(drawer_page.toggle_button_width).to be <= 1 # not visible to pointer users

      drawer_page.focus_toggle_button

      expect(drawer_page.toggle_button_width).to be > 1

      drawer_page.expand_with_keyboard
      expect(page).to have_selector(".chat-drawer.is-expanded")
      expect(page).to have_selector(".c-navbar__star-channel-button")
      expect(page).to have_selector(".c-navbar__filter")
      expect(page).to have_selector(".c-navbar__threads-list-button")

      drawer_page.collapse
      expect(page).to have_selector(".chat-drawer:not(.is-expanded)")

      drawer_page.expand
      expect(page).to have_selector(".chat-drawer.is-expanded")
      expect(page).to have_selector(".c-navbar__star-channel-button")
      expect(page).to have_selector(".c-navbar__filter")
      expect(page).to have_selector(".c-navbar__threads-list-button")
    end
  end

  context "when going from drawer to full page" do
    fab!(:channel_1, :chat_channel)
    fab!(:channel_2, :chat_channel)
    fab!(:user_1, :user)
    fab!(:membership_1) { channel_1.add(current_user) }
    fab!(:membership_2) { channel_2.add(current_user) }
    fab!(:other_membership_1) { channel_1.add(user_1) }
    fab!(:other_membership_2) { channel_2.add(user_1) }

    let(:sidebar_page) { PageObjects::Pages::ChatSidebar.new }

    before { current_user.upsert_custom_fields(::Chat::LAST_CHAT_CHANNEL_ID => channel_1.id) }

    it "correctly resets subscriptions" do
      visit("/")

      chat_page.open_from_header
      drawer_page.maximize
      chat_page.minimize_full_page
      drawer_page.maximize

      expect(page).to have_css(".chat-channel.--loaded[data-id='#{channel_1.id}']")

      Fabricate(
        :chat_message,
        chat_channel: channel_1,
        user: user_1,
        use_service: true,
        message: "onlyonce",
      )

      expect(page).to have_content("onlyonce", count: 1)

      sidebar_page.open_channel(channel_2)

      expect(page).to have_css(".chat-channel.--loaded[data-id='#{channel_2.id}']")
      expect(page).to have_no_content("onlyonce")
    end
  end

  context "when subfolder install" do
    fab!(:channel, :chat_channel)

    before do
      current_user.upsert_custom_fields(::Chat::LAST_CHAT_CHANNEL_ID => channel.id)
      channel.add(current_user)
      set_subfolder "/discuss"
    end

    it "works to go from full page to drawer" do
      visit("/discuss/chat")
      chat_page.minimize_full_page

      expect(drawer_page).to have_open_channel(channel)
    end

    it "returns to the homepage when toggling chat icon after expanding drawer to full page" do
      SiteSetting.chat_separate_sidebar_mode = "fullscreen"
      SiteSetting.top_menu = "categories|latest|new"

      visit("/discuss/")
      chat_page.open_from_header
      expect(page).to have_css("body.has-drawer-chat")

      drawer_page.maximize
      expect(page).to have_css("body.has-full-page-chat")

      find(".chat-header-icon").click

      expect(page).to have_current_path("/discuss/categories")
      expect(page).to have_no_css("body.has-full-page-chat")
    end

    it "does not double the subfolder when returning to a chat channel via the header icon after a programmatic navigation" do
      visit("/discuss/chat")
      expect(page).to have_css("html.has-chat")

      find(".title a").click
      expect(page).to have_current_path("/discuss/")

      find(".sidebar-section-link.channel-#{channel.id}").click
      expect(page).to have_css("body.has-drawer-chat")

      drawer_page.close

      find(".chat-header-icon").click

      expect(page).to have_current_path("/discuss/")
      expect(page).to have_css("body.has-drawer-chat")
      expect(page).to have_css(".chat-channel.--loaded[data-id='#{channel.id}']")
    end
  end

  context "when sending a message from a thread while viewing a topic" do
    fab!(:post1, :post)
    fab!(:post2) { Fabricate(:post, topic: post1.topic) }
    fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }
    fab!(:thread) { Fabricate(:chat_thread, channel: channel, with_replies: 1, use_service: true) }
    fab!(:membership) do
      Fabricate(:user_chat_channel_membership, user: current_user, chat_channel: channel)
    end

    let(:topic_page) { PageObjects::Pages::Topic.new }
    let(:thread_list_page) { PageObjects::Components::Chat::ThreadList.new }
    let(:thread_page) { PageObjects::Pages::ChatThread.new }

    before { Jobs.run_immediately! }

    it "has topic context" do
      tested_context = {}
      blk = ->(*, context) { tested_context = context }
      DiscourseEvent.on(:chat_message_created, &blk)

      topic_page.visit_topic(post1.topic)
      chat_page.open_from_header
      drawer_page.open_channel(channel)
      drawer_page.open_thread_list
      thread_list_page.open_thread(thread)
      thread_page.send_message

      try_until_success do
        expect(tested_context.dig(:context, :post_ids)).to eq([post1.id, post2.id])
        expect(tested_context.dig(:context, :topic_id)).to eq(post1.topic_id)
      end
    ensure
      DiscourseEvent.off(:chat_message_created, &blk)
    end
  end

  describe "with chat footer" do
    it "hides footer nav when only channels are accessible" do
      SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:staff]

      visit("/")
      chat_page.open_from_header

      expect(page).to have_no_css(".chat-drawer .c-footer")
    end

    context "when clicking footer nav items" do
      fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }
      fab!(:other_user, :user)

      before do
        SiteSetting.chat_threads_enabled = true
        channel.add(current_user)
        channel.add(other_user)
      end

      it "shows active state" do
        visit("/")
        chat_page.open_from_header

        drawer_page.click_direct_messages
        expect(page).to have_css("#c-footer-direct-messages.--active")
      end

      context "with viewable threads" do
        fab!(:message) { Fabricate(:chat_message, chat_channel: channel, user: current_user) }
        fab!(:thread) do
          chat_thread_with_replies(
            channel: channel,
            original_message: message,
            reply_users: [other_user],
          )
        end

        it "redirects to correct route" do
          visit("/")
          chat_page.open_from_header

          drawer_page.click_direct_messages
          expect(drawer_page).to have_open_direct_messages

          drawer_page.click_channels
          expect(drawer_page).to have_open_channels

          drawer_page.click_user_threads
          expect(drawer_page).to have_open_user_threads
          expect(drawer_page).to have_css(".c-user-thread[data-id='#{thread.id}']")
        end
      end
    end
  end
end

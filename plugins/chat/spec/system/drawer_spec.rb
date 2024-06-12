# frozen_string_literal: true

RSpec.describe "Drawer", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:drawer_page) { PageObjects::Pages::ChatDrawer.new }

  before do
    chat_system_bootstrap
    sign_in(current_user)
    chat_page.prefers_drawer
  end

  context "when on channel" do
    fab!(:channel) { Fabricate(:chat_channel) }
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

      it "opens channel settings page" do
        expect(drawer_page).to have_channel_settings
      end

      it "has tabs for settings and members" do
        expect(drawer_page).to have_css(".c-channel-info__nav li a", text: "Settings")
        expect(drawer_page).to have_css(".c-channel-info__nav li a", text: "Members")
      end

      it "opens correct tab when clicked" do
        page.find(".c-channel-info__nav li a", text: "Members").click
        expect(drawer_page).to have_channel_members

        page.find(".c-channel-info__nav li a", text: "Settings").click
        expect(drawer_page).to have_channel_settings
      end

      it "has a back button" do
        expect(drawer_page).to have_css(".c-navbar__back-button")
      end
    end
  end

  context "when opening" do
    it "uses stored size" do
      visit("/") # we need to visit the page first to set the local storage

      page.execute_script "window.localStorage.setItem('discourse_chat_drawer_size_width','500');"
      page.execute_script "window.localStorage.setItem('discourse_chat_drawer_size_height','500');"

      visit("/")

      chat_page.open_from_header

      expect(page.find(".chat-drawer").native.style("width")).to eq("500px")
      expect(page.find(".chat-drawer").native.style("height")).to eq("500px")
    end

    it "has a default size" do
      visit("/")

      chat_page.open_from_header

      expect(page.find(".chat-drawer").native.style("width")).to eq("400px")
      expect(page.find(".chat-drawer").native.style("height")).to eq("530px")
    end
  end

  context "when toggling open/close" do
    it "toggles a css class on body" do
      visit("/")

      chat_page.open_from_header

      expect(page.find("body.chat-drawer-active")).to be_visible

      drawer_page.close

      expect(page.find("body:not(.chat-drawer-active)")).to be_visible
    end
  end

  context "when closing the drawer" do
    fab!(:channel_1) { Fabricate(:chat_channel) }
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }

    before { channel_1.add(current_user) }

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

  context "when clicking the drawer's header" do
    it "collapses the drawer" do
      visit("/")
      chat_page.open_from_header
      expect(page).to have_selector(".chat-drawer.is-expanded")

      page.find(".c-navbar").click

      expect(page).to have_selector(".chat-drawer:not(.is-expanded)")
    end
  end

  context "when going from drawer to full page" do
    fab!(:channel_1) { Fabricate(:chat_channel) }
    fab!(:channel_2) { Fabricate(:chat_channel) }
    fab!(:user_1) { Fabricate(:user) }

    before do
      current_user.upsert_custom_fields(::Chat::LAST_CHAT_CHANNEL_ID => channel_1.id)
      channel_1.add(current_user)
      channel_2.add(current_user)
      channel_1.add(user_1)
      channel_2.add(user_1)
    end

    it "correctly resets subscriptions" do
      visit("/")

      chat_page.open_from_header
      drawer_page.maximize
      chat_page.minimize_full_page
      drawer_page.maximize

      Fabricate(
        :chat_message,
        chat_channel: channel_1,
        user: user_1,
        use_service: true,
        message: "onlyonce",
      )

      expect(page).to have_content("onlyonce", count: 1)

      chat_page.visit_channel(channel_2)

      expect(page).to have_content("onlyonce", count: 0)
    end
  end

  context "when subfolder install" do
    fab!(:channel) { Fabricate(:chat_channel) }

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
  end

  context "when sending a message from topic" do
    fab!(:topic)
    fab!(:posts) { Fabricate.times(5, :post, topic: topic) }
    fab!(:channel) { Fabricate(:chat_channel) }
    fab!(:membership) do
      Fabricate(:user_chat_channel_membership, user: current_user, chat_channel: channel)
    end

    let(:topic_page) { PageObjects::Pages::Topic.new }

    context "when on a channel" do
      xit "has context" do
        ::Chat::CreateMessage
          .expects(:call)
          .with do |value|
            value["topic_id"] === topic.id.to_s &&
              value["post_ids"] === [posts[1].id.to_s, posts[2].id.to_s, posts[3].id.to_s]
          end

        topic_page.visit_topic(topic, post_number: 3)
        chat_page.open_from_header
        drawer_page.open_channel(channel)
        channel_page.send_message
      end
    end

    context "when on a thread" do
      before { channel.update!(threading_enabled: true) }

      fab!(:thread_1) { Fabricate(:chat_thread, channel: channel) }

      let(:thread_list_page) { PageObjects::Components::Chat::ThreadList.new }
      let(:thread_page) { PageObjects::Pages::ChatThread.new }

      xit "has context" do
        ::Chat::CreateMessage
          .expects(:call)
          .with do |value|
            value["topic_id"] === topic.id.to_s &&
              value["post_ids"] === [posts[1].id.to_s, posts[2].id.to_s, posts[3].id.to_s]
          end

        topic_page.visit_topic(topic, post_number: 3)
        chat_page.open_from_header
        drawer_page.open_channel(channel)
        drawer_page.open_thread_list
        thread_list_page.open_thread(thread_1)
        thread_page.send_message
      end
    end
  end

  describe "with chat footer" do
    it "opens channels list by default" do
      visit("/")
      chat_page.open_from_header

      expect(drawer_page).to have_open_channels
    end

    it "shows footer nav when 2 or more tabs are accessible" do
      visit("/")
      chat_page.open_from_header

      expect(page).to have_css(".chat-drawer .c-footer")
      expect(page).to have_css(".chat-drawer .c-footer__item", count: 2)
    end

    it "hides footer nav when only channels are accessible" do
      SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:staff]

      visit("/")
      chat_page.open_from_header

      expect(page).to have_no_css(".chat-drawer .c-footer")
    end

    context "when clicking footer nav items" do
      fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }

      before do
        SiteSetting.chat_threads_enabled = true
        channel.add(current_user)
      end

      it "shows active state" do
        visit("/")
        chat_page.open_from_header

        drawer_page.click_direct_messages
        expect(page).to have_css("#c-footer-direct-messages.--active")
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
      end
    end
  end
end

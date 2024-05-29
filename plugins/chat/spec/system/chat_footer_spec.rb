# frozen_string_literal: true

RSpec.describe "Mobile Chat footer", type: :system, mobile: true do
  fab!(:user)
  fab!(:user_2) { Fabricate(:user) }
  fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }
  fab!(:message) { Fabricate(:chat_message, chat_channel: channel, user: user) }
  let(:chat_page) { PageObjects::Pages::Chat.new }

  before do
    chat_system_bootstrap
    sign_in(user)
    channel.add(user)
    channel.add(user_2)
  end

  context "with multiple tabs" do
    it "shows footer" do
      SiteSetting.chat_threads_enabled = false

      visit("/")
      chat_page.open_from_header

      expect(page).to have_css(".c-footer")
      expect(page).to have_css(".c-footer__item", count: 2)
      expect(page).to have_css("#c-footer-direct-messages")
      expect(page).to have_css("#c-footer-channels")
    end

    it "hides footer when channel is open" do
      chat_page.visit_channel(channel)

      expect(page).to have_no_css(".c-footer")
    end

    it "redirects the user to the channels tab" do
      visit("/")
      chat_page.open_from_header

      expect(page).to have_current_path("/chat/channels")
    end

    context "when user is a member of at least one channel with threads" do
      it "shows threads tab when user has threads" do
        SiteSetting.chat_threads_enabled = true

        visit("/")
        chat_page.open_from_header

        expect(page).to have_css(".c-footer")
        expect(page).to have_css("#c-footer-threads")
      end
    end

    context "when user is not a member of any channel with threads" do
      before do
        other_channel = Fabricate(:chat_channel, threading_enabled: false)
        other_channel.add(user)
        channel.remove(user)
      end

      it "shows threads tab when user has threads" do
        SiteSetting.chat_threads_enabled = true

        visit("/")
        chat_page.open_from_header

        expect(page).to have_css(".c-footer")
        expect(page).to have_no_css("#c-footer-threads")
      end
    end
  end

  context "with only 1 tab" do
    before do
      SiteSetting.chat_threads_enabled = false
      SiteSetting.direct_message_enabled_groups = "3" # staff only
    end

    it "does not render footer" do
      visit("/")
      chat_page.open_from_header

      expect(page).to have_no_css(".c-footer")
    end

    it "redirects user to channels page" do
      visit("/")
      chat_page.open_from_header

      expect(page).to have_current_path("/chat/channels")
    end
  end

  describe "badges" do
    context "for channels" do
      it "is unread for messages" do
        Fabricate(:chat_message, chat_channel: channel)

        visit("/")
        chat_page.open_from_header

        expect(page).to have_css("#c-footer-channels .c-unread-indicator")
      end

      it "is urgent for mentions" do
        Jobs.run_immediately!

        visit("/")
        chat_page.open_from_header

        Fabricate(
          :chat_message_with_service,
          chat_channel: channel,
          message: "hello @#{user.username}",
          user: user_2,
        )

        expect(page).to have_css("#c-footer-channels .c-unread-indicator.-urgent", text: "1")
      end
    end

    context "for direct messages" do
      fab!(:dm_channel) { Fabricate(:direct_message_channel, users: [user]) }
      fab!(:dm_message) { Fabricate(:chat_message, chat_channel: dm_channel) }

      it "is urgent" do
        visit("/")
        chat_page.open_from_header

        expect(page).to have_css("#c-footer-direct-messages .c-unread-indicator.-urgent")
      end
    end

    context "for threads" do
      fab!(:thread) { Fabricate(:chat_thread, channel: channel, original_message: message) }
      fab!(:thread_message) { Fabricate(:chat_message, chat_channel: channel, thread: thread) }

      it "is unread" do
        SiteSetting.chat_threads_enabled = true

        visit("/")
        chat_page.open_from_header

        expect(page).to have_css("#c-footer-threads .c-unread-indicator")
      end
    end
  end
end

# frozen_string_literal: true

RSpec.describe "Mobile Chat footer", type: :system, mobile: true do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:other_user) { Fabricate(:user) }
  fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }
  fab!(:message) { Fabricate(:chat_message, chat_channel: channel, user: current_user) }
  let(:chat_page) { PageObjects::Pages::Chat.new }

  before do
    chat_system_bootstrap
    sign_in(current_user)
    channel.add(current_user)
    channel.add(other_user)
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
        other_channel.add(current_user)
        channel.remove(current_user)
      end

      it "does not show my threads" do
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
          message: "hello @#{current_user.username}",
          user: other_user,
        )

        expect(page).to have_css("#c-footer-channels .c-unread-indicator.-urgent", text: "1")
      end
    end

    context "for direct messages" do
      fab!(:dm_channel) { Fabricate(:direct_message_channel, users: [current_user]) }
      fab!(:dm_message) { Fabricate(:chat_message, chat_channel: dm_channel) }

      it "is urgent" do
        visit("/")
        chat_page.open_from_header

        expect(page).to have_css("#c-footer-direct-messages .c-unread-indicator.-urgent")
      end
    end

    context "for my threads" do
      context "with public channels" do
        fab!(:thread) { Fabricate(:chat_thread, channel: channel, original_message: message) }
        fab!(:thread_message) { Fabricate(:chat_message, chat_channel: channel, thread: thread) }

        before { SiteSetting.chat_threads_enabled = true }

        it "is unread" do
          visit("/")
          chat_page.open_from_header

          expect(page).to have_css("#c-footer-threads .c-unread-indicator")
        end

        it "is not unread when thread is from a muted channel" do
          channel.membership_for(current_user).update!(muted: true)

          visit("/")
          chat_page.open_from_header

          expect(page).to have_no_css("#c-footer-threads .c-unread-indicator")
        end

        it "is urgent for watched thread messages" do
          thread.membership_for(current_user).update!(
            notification_level: ::Chat::NotificationLevels.all[:watching],
          )

          visit("/")
          chat_page.open_from_header

          expect(page).to have_css("#c-footer-threads .c-unread-indicator.-urgent")
        end
      end

      context "with direct messages" do
        fab!(:dm_channel) do
          Fabricate(
            :direct_message_channel,
            threading_enabled: true,
            users: [current_user, other_user],
          )
        end
        fab!(:dm_message) { Fabricate(:chat_message, chat_channel: dm_channel, user: current_user) }
        fab!(:dm_thread) do
          Fabricate(:chat_thread, channel: dm_channel, original_message: dm_message)
        end
        fab!(:dm_thread_message) do
          Fabricate(:chat_message, chat_channel: dm_channel, thread: dm_thread, user: other_user)
        end

        before { SiteSetting.chat_threads_enabled = true }

        it "is unread" do
          visit("/")
          chat_page.open_from_header

          expect(page).to have_css("#c-footer-threads .c-unread-indicator")
        end
      end
    end
  end
end

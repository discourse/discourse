# frozen_string_literal: true

describe "Thread tracking state | drawer", type: :system do
  include ActiveSupport::Testing::TimeHelpers

  fab!(:current_user) { Fabricate(:admin) }
  fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }
  fab!(:other_user) { Fabricate(:user) }
  fab!(:thread) { Fabricate(:chat_thread, channel: channel) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:thread_page) { PageObjects::Pages::ChatThread.new }
  let(:thread_list_page) { PageObjects::Components::Chat::ThreadList.new }
  let(:drawer_page) { PageObjects::Pages::ChatDrawer.new }

  before do
    chat_system_bootstrap(current_user, [channel])
    chat_system_user_bootstrap(user: other_user, channel: channel)
    sign_in(current_user)
    thread.add(current_user)
  end

  context "when the user has unread messages for a thread" do
    fab!(:message_1) do
      Fabricate(:chat_message, thread: thread, user: current_user, use_service: true)
    end
    fab!(:message_2) { Fabricate(:chat_message, thread: thread, use_service: true) }

    it "shows the count of threads with unread messages on the thread list button" do
      visit("/")
      chat_page.open_from_header
      drawer_page.open_channel(channel)
      expect(drawer_page).to have_unread_thread_indicator(count: 1)
    end

    it "shows an indicator on the unread thread in the list" do
      visit("/")
      chat_page.open_from_header
      drawer_page.open_channel(channel)
      drawer_page.open_thread_list
      expect(drawer_page).to have_open_thread_list
      expect(thread_list_page).to have_unread_item(thread.id)
    end

    it "shows an urgent indicator on the watched thread in the list" do
      thread.membership_for(current_user).update!(
        notification_level: ::Chat::NotificationLevels.all[:watching],
      )

      visit("/")
      chat_page.open_from_header
      drawer_page.open_channel(channel)
      drawer_page.open_thread_list
      expect(drawer_page).to have_open_thread_list
      expect(thread_list_page).to have_unread_item(thread.id, urgent: true)
    end

    it "marks the thread as read and removes both indicators when the user opens it" do
      skip("Flaky on CI") if ENV["CI"]

      visit("/")
      chat_page.open_from_header
      drawer_page.open_channel(channel)
      drawer_page.open_thread_list
      thread_list_page.open_thread(thread)

      expect(drawer_page).to have_no_unread_thread_indicator

      # this is a hack to ensure we don't destroy the component as it's doing the mark as read request
      sleep 1

      drawer_page.back

      expect(thread_list_page).to have_no_unread_item(thread.id)
    end

    xit "shows unread indicators for the header icon and the list when a new unread arrives" do
      thread.membership_for(current_user).update!(last_read_message_id: message_2.id)
      visit("/")
      chat_page.open_from_header
      drawer_page.open_channel(channel)
      drawer_page.open_thread_list
      expect(drawer_page).to have_no_unread_thread_indicator
      expect(thread_list_page).to have_no_unread_item(thread.id)
      travel_to(1.minute.from_now)
      Fabricate(:chat_message, thread: thread, user: other_user, use_service: true)
      expect(drawer_page).to have_unread_thread_indicator(count: 1)
      expect(thread_list_page).to have_unread_item(thread.id)
    end

    describe "channel index unread indicators" do
      fab!(:other_channel) { Fabricate(:chat_channel) }

      before { other_channel.add(current_user) }

      it "shows an unread indicator for the channel with unread threads in the index" do
        visit("/")
        chat_page.open_from_header
        expect(drawer_page).to have_unread_channel(channel)
      end

      it "does not show an unread indicator for the channel if the user has visited the channel since the unread thread message arrived" do
        channel.membership_for(current_user).update!(last_viewed_at: Time.zone.now)
        visit("/")
        chat_page.open_from_header
        expect(drawer_page).to have_no_unread_channel(channel)
      end

      it "clears the index unread indicator for the channel when opening it but keeps the thread list unread indicator" do
        visit("/")
        chat_page.open_from_header
        drawer_page.open_channel(channel)
        expect(channel_page).to have_unread_thread_indicator(count: 1)
        drawer_page.back
        expect(drawer_page).to have_no_unread_channel(channel)
      end

      it "does not show an unread indicator for the channel index if a new thread message arrives while the user is looking at the channel" do
        visit("/")
        chat_page.open_from_header
        expect(drawer_page).to have_unread_channel(channel)
        drawer_page.open_channel(channel)
        Fabricate(:chat_message, thread: thread, user: other_user, use_service: true)
        drawer_page.back
        expect(drawer_page).to have_no_unread_channel(channel)
      end

      it "shows an unread indicator for the channel index if a new thread message arrives while the user is not looking at the channel" do
        visit("/")
        chat_page.open_from_header
        drawer_page.open_channel(channel)
        drawer_page.back
        expect(drawer_page).to have_no_unread_channel(channel)
        travel_to(1.minute.from_now)
        Fabricate(:chat_message, thread: thread, user: other_user, use_service: true)
        expect(drawer_page).to have_unread_channel(channel)
      end
    end
  end
end

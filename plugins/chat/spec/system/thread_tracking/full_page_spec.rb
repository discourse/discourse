# frozen_string_literal: true

describe "Thread tracking state | full page", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }
  fab!(:other_user) { Fabricate(:user) }
  fab!(:thread) { Fabricate(:chat_thread, channel: channel) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:thread_page) { PageObjects::Pages::ChatThread.new }
  let(:thread_list_page) { PageObjects::Components::Chat::ThreadList.new }
  let(:sidebar_page) { PageObjects::Pages::Sidebar.new }

  before do
    chat_system_bootstrap(current_user, [channel])
    sign_in(current_user)
    thread.add(current_user)
  end

  context "when the user has unread messages for a thread" do
    fab!(:message_1) do
      Fabricate(:chat_message, chat_channel: channel, thread: thread, user: current_user)
    end
    fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel, thread: thread) }

    it "shows the count of threads with unread messages on the thread list button" do
      chat_page.visit_channel(channel)
      expect(channel_page).to have_unread_thread_indicator(count: 1)
    end

    it "does not include threads with deleted original messages in the count of threads with unread messages" do
      thread.original_message.trash!
      chat_page.visit_channel(channel)
      expect(thread_page).to have_no_unread_list_indicator
    end

    it "shows an indicator on the unread thread in the list" do
      chat_page.visit_channel(channel)
      channel_page.open_thread_list
      expect(thread_list_page).to have_unread_item(thread.id, count: 1)
    end

    it "marks the thread as read and removes both indicators when the user opens it" do
      chat_page.visit_channel(channel)
      channel_page.open_thread_list
      thread_list_page.item_by_id(thread.id).click
      expect(thread_page).to have_no_unread_list_indicator
      thread_page.back_to_previous_route
      expect(thread_list_page).to have_no_unread_item(thread.id)
    end

    it "shows unread indicators for the header of the list when a new unread arrives" do
      thread.membership_for(current_user).update!(last_read_message_id: message_2.id)
      chat_page.visit_channel(channel)
      channel_page.open_thread_list
      expect(thread_list_page).to have_no_unread_item(thread.id)
      Fabricate(:chat_message, chat_channel: channel, thread: thread)
      expect(thread_list_page).to have_unread_item(thread.id)
    end

    it "does not change the unread indicator for the header icon when the user is not a member of the thread" do
      thread.remove(current_user)
      chat_page.visit_channel(channel)
      expect(channel_page).to have_no_unread_thread_indicator
      Fabricate(:chat_message, chat_channel: channel, thread: thread)
      expect(channel_page).to have_no_unread_thread_indicator
      channel_page.open_thread_list
      expect(thread_list_page).to have_no_unread_item(thread.id)
    end

    it "allows the user to change their tracking level for an existing thread" do
      chat_page.visit_thread(thread)
      thread_page.notification_level = :normal
      expect(thread_page).to have_notification_level("normal")
    end

    it "allows the user to start tracking a thread they have not replied to" do
      new_thread = Fabricate(:chat_thread, channel: channel)
      Fabricate(:chat_message, chat_channel: channel, thread: new_thread)
      chat_page.visit_thread(new_thread)
      thread_page.notification_level = :tracking
      expect(thread_page).to have_notification_level("tracking")
      chat_page.visit_channel(channel)
      channel_page.open_thread_list
      expect(thread_list_page).to have_thread(new_thread)
    end

    describe "sidebar unread indicators" do
      fab!(:other_channel) { Fabricate(:chat_channel) }

      before do
        other_channel.add(current_user)
        SiteSetting.navigation_menu = "sidebar"
      end

      it "shows an unread indicator for the channel with unread threads in the sidebar" do
        chat_page.visit_channel(other_channel)
        expect(sidebar_page).to have_unread_channel(channel)
      end

      it "does not show an unread indicator for the channel if the user has visited the channel since the unread thread message arrived" do
        channel.membership_for(current_user).update!(last_viewed_at: Time.zone.now)
        chat_page.visit_channel(other_channel)
        expect(sidebar_page).to have_no_unread_channel(channel)
      end

      it "clears the sidebar unread indicator for the channel when opening it but keeps the thread list unread indicator" do
        chat_page.visit_channel(channel)
        expect(sidebar_page).to have_no_unread_channel(channel)
        expect(channel_page).to have_unread_thread_indicator(count: 1)
      end

      it "does not show an unread indicator for the channel sidebar if a new thread message arrives while the user is looking at the channel" do
        chat_page.visit_channel(channel)
        expect(sidebar_page).to have_no_unread_channel(channel)
        Fabricate(:chat_message, thread: thread)
        expect(sidebar_page).to have_no_unread_channel(channel)
      end

      it "shows an unread indicator for the channel sidebar if a new thread message arrives while the user is not looking at the channel" do
        chat_page.visit_channel(channel)
        expect(sidebar_page).to have_no_unread_channel(channel)
        chat_page.visit_channel(other_channel)
        Fabricate(:chat_message, thread: thread)
        expect(sidebar_page).to have_unread_channel(channel)
      end
    end

    context "when the user's notification level for the thread is set to normal" do
      before { thread.membership_for(current_user).update!(notification_level: :normal) }

      it "does not show a the count of threads with unread messages on the thread list button" do
        chat_page.visit_channel(channel)
        expect(channel_page).to have_no_unread_thread_indicator
      end

      it "does not show an indicator on the unread thread in the list" do
        chat_page.visit_channel(channel)
        channel_page.open_thread_list
        expect(thread_list_page).to have_no_unread_item(thread.id)
      end
    end
  end
end

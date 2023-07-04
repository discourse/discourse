# frozen_string_literal: true

describe "Thread tracking state | drawer", type: :system do
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
    SiteSetting.enable_experimental_chat_threaded_discussions = true
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

    it "marks the thread as read and removes both indicators when the user opens it" do
      visit("/")
      chat_page.open_from_header
      drawer_page.open_channel(channel)
      drawer_page.open_thread_list
      thread_list_page.item_by_id(thread.id).click
      expect(drawer_page).to have_no_unread_thread_indicator
      drawer_page.open_thread_list
      expect(thread_list_page).to have_no_unread_item(thread.id)
    end

    it "shows unread indicators for the header icon and the list when a new unread arrives" do
      thread.membership_for(current_user).update!(last_read_message_id: message_2.id)
      visit("/")
      chat_page.open_from_header
      drawer_page.open_channel(channel)
      drawer_page.open_thread_list
      expect(drawer_page).to have_no_unread_thread_indicator
      expect(thread_list_page).to have_no_unread_item(thread.id)
      Fabricate(:chat_message, chat_channel: channel, thread: thread)
      expect(drawer_page).to have_unread_thread_indicator(count: 1)
      expect(thread_list_page).to have_unread_item(thread.id)
    end
  end
end

# frozen_string_literal: true

RSpec.describe "Drawer - threads", type: :system do
  fab!(:current_user, :user)
  fab!(:other_user, :user)
  fab!(:channel_1) { Fabricate(:chat_channel, threading_enabled: true) }

  let(:drawer_page) { PageObjects::Pages::ChatDrawer.new }

  before do
    SiteSetting.chat_threads_enabled = true
    channel_1.add(current_user)
    channel_1.add(other_user)
    chat_system_bootstrap
    sign_in(current_user)
  end

  context "when user has viewable threads" do
    before do
      message = Fabricate(:chat_message, chat_channel: channel_1, user: current_user)
      thread = Fabricate(:chat_thread, channel: channel_1, original_message: message)
      thread.add(current_user)
      Fabricate(:chat_message, chat_channel: channel_1, thread: thread, user: other_user)
      thread.set_replies_count_cache(1, update_db: true)
    end

    it "shows a button for chat search" do
      drawer_page.visit_user_threads
      drawer_page.open_chat_search

      expect(drawer_page).to have_open_chat_search
    end
  end
end

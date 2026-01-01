# frozen_string_literal: true

RSpec.describe "Drawer - threads", type: :system do
  fab!(:current_user, :user)
  fab!(:channel_1) { Fabricate(:chat_channel, threading_enabled: true) }
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1, user: current_user) }
  fab!(:thread_1) { Fabricate(:chat_thread, channel: channel_1, original_message: message_1) }

  let(:drawer_page) { PageObjects::Pages::ChatDrawer.new }

  before do
    SiteSetting.chat_threads_enabled = true
    channel_1.add(current_user)
    thread_1.add(current_user)
    chat_system_bootstrap
    sign_in(current_user)
  end

  it "shows a button for chat search" do
    drawer_page.visit_user_threads
    drawer_page.open_chat_search

    expect(drawer_page).to have_open_chat_search
  end
end

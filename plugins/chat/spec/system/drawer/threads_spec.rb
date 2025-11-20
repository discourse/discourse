# frozen_string_literal: true

RSpec.describe "Drawer - threads", type: :system do
  fab!(:current_user, :user)
  fab!(:channel_1) { Fabricate(:chat_channel, threading_enabled: true) }

  let(:drawer_page) { PageObjects::Pages::ChatDrawer.new }

  before do
    SiteSetting.chat_threads_enabled = true
    channel_1.add(current_user)
    chat_system_bootstrap
    sign_in(current_user)
  end

  it "shows a button for chat search" do
    drawer_page.visit_user_threads

    expect(page).to have_selector(".chat-channel-search-btn")
  end
end

# frozen_string_literal: true

describe "Thread preload", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:chat_channel) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:thread_page) { PageObjects::Pages::ChatThread.new }

  before do
    SiteSetting.enable_experimental_chat_threaded_discussions = true
    chat_system_bootstrap(current_user)
    channel_1.add(current_user)
    channel_1.update!(threading_enabled: true)
    sign_in(current_user)
  end

  context "when hovering a thread indicator" do
    it "preloads the thread" do
      thread =
        chat_thread_chain_bootstrap(channel: channel_1, users: [current_user, Fabricate(:user)])
      chat_page.visit_channel(channel_1)

      channel_page.message_thread_indicator(thread.original_message).hover

      expect(page).to have_selector("link#thread-preload-#{thread.id}.is-preloaded", visible: false)
      expect(page).to have_selector(
        "link#thread-preload-messages-#{thread.id}.is-preloaded",
        visible: false,
      )

      page.driver.browser.network_conditions = { offline: true }

      channel_page.message_thread_indicator(thread.original_message).click

      expect(thread_page).to have_message(text: thread.replies.last.message)
    ensure
      page.driver.browser.network_conditions = { offline: false }
    end
  end
end

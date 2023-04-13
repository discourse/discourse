# frozen_string_literal: true

RSpec.describe "Chat message - channel", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:other_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:chat_channel) }
  fab!(:thread_1) do
    chat_thread_chain_bootstrap(channel: channel_1, users: [current_user, other_user])
  end

  let(:cdp) { PageObjects::CDP.new }
  let(:chat) { PageObjects::Pages::Chat.new }
  let(:channel) { PageObjects::Pages::ChatChannel.new }
  let(:message_1) { thread_1.chat_messages.first }

  before do
    chat_system_bootstrap
    channel_1.update!(threading_enabled: true)
    channel_1.add(current_user)
    channel_1.add(other_user)
    SiteSetting.enable_experimental_chat_threaded_discussions = true
    sign_in(current_user)
  end

  context "when hovering a message" do
    it "adds an active class" do
      chat.visit_thread(thread_1)

      channel.hover_message(message_1)

      expect(page).to have_css(
        ".chat-thread[data-id='#{thread_1.id}'] [data-id='#{message_1.id}'] .chat-message.is-active",
      )
    end
  end

  context "when copying link to a message" do
    before { cdp.allow_clipboard }

    it "copies the link to the thread" do
      chat.visit_thread(thread_1)

      channel.copy_link(message_1)

      expect(cdp.read_clipboard).to include("/chat/c/-/#{channel_1.id}/t/#{thread_1.id}")
    end
  end
end

# frozen_string_literal: true

RSpec.describe "Chat message", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:chat_channel) }
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:channel) { PageObjects::Pages::ChatChannel.new }

  before { chat_system_bootstrap }

  context "when hovering a message" do
    before do
      channel_1.add(current_user)
      sign_in(current_user)
    end

    it "adds an active class" do
      chat.visit_channel(channel_1)
      channel.hover_message(message_1)

      expect(page).to have_css("[data-id='#{message_1.id}'] .chat-message.is-active")
    end
  end
end

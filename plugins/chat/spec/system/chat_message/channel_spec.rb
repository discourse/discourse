# frozen_string_literal: true

RSpec.describe "Chat message - channel", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:chat_channel) }
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }

  let(:cdp) { PageObjects::CDP.new }
  let(:chat) { PageObjects::Pages::Chat.new }
  let(:channel) { PageObjects::Pages::ChatChannel.new }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  context "when hovering a message" do
    it "adds an active class" do
      chat.visit_channel(channel_1)

      channel.hover_message(message_1)

      expect(page).to have_css(
        ".chat-channel[data-id='#{channel_1.id}'] .chat-message-container[data-id='#{message_1.id}'].-active",
      )
    end
  end

  context "when copying link to a message" do
    before { cdp.allow_clipboard }

    it "copies the link to the message" do
      chat.visit_channel(channel_1)

      channel.copy_link(message_1)

      expect(cdp.read_clipboard).to include("/chat/c/-/#{channel_1.id}/#{message_1.id}")
    end

    context "when the message is part of a thread" do
      before { channel_1.update!(threading_enabled: true) }

      fab!(:thread_1) do
        chat_thread_chain_bootstrap(
          channel: channel_1,
          users: [current_user, Fabricate(:user)],
          messages_count: 2,
        )
      end

      it "copies the link to the message and not to the thread" do
        chat.visit_channel(channel_1)

        channel.copy_link(thread_1.original_message)

        expect(cdp.read_clipboard).to include(
          "/chat/c/-/#{channel_1.id}/#{thread_1.original_message.id}",
        )
      end
    end
  end
end

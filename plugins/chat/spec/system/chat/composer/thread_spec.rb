# frozen_string_literal: true

RSpec.describe "Chat | composer | thread", type: :system do
  fab!(:channel_1) { Fabricate(:chat_channel, threading_enabled: true) }
  fab!(:current_user) { Fabricate(:admin) }
  fab!(:message_1) do
    Fabricate(:chat_message, chat_channel: channel_1, user: current_user, use_service: true)
  end
  fab!(:message_2) do
    Fabricate(:chat_message, user: current_user, in_reply_to: message_1, use_service: true)
  end

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:thread_page) { PageObjects::Pages::ChatThread.new }
  let(:cdp) { PageObjects::CDP.new }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  describe "edit message" do
    it "adds the edit indicator" do
      chat_page.visit_thread(message_2.thread)
      thread_page.edit_message(message_2)

      expect(thread_page.composer).to be_editing_message(message_2)
    end

    it "updates the message instantly" do
      chat_page.visit_thread(message_2.thread)

      cdp.with_network_disconnected do
        thread_page.edit_message(message_2, "instant")

        expect(thread_page.messages).to have_message(
          text: message_2.message + " instant",
          persisted: false,
        )
      end
    end

    context "when pressing escape" do
      it "cancels editing" do
        chat_page.visit_thread(message_2.thread)
        thread_page.edit_message(message_2)
        thread_page.composer.cancel_shortcut

        expect(thread_page.composer).to be_editing_no_message
        expect(thread_page.composer).to be_blank
      end
    end

    context "when closing edited message" do
      it "cancels editing" do
        chat_page.visit_thread(message_2.thread)
        thread_page.edit_message(message_2)
        thread_page.composer.cancel_editing

        expect(thread_page.composer).to be_editing_no_message
        expect(thread_page.composer.value).to be_blank
      end
    end
  end
end

# frozen_string_literal: true

describe "Thread preview", type: :system do
  fab!(:current_user) { Fabricate(:admin) }
  fab!(:channel_1) { Fabricate(:chat_channel, threading_enabled: true) }
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1, use_service: true) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  context "when message has no thread" do
    it "shows no preview" do
      chat_page.visit_channel(channel_1)

      expect(channel_page.messages).to have_message(id: message_1.id)
      expect(channel_page).to have_no_thread_indicator(message_1)
    end
  end

  context "when message has thread with no replies" do
    before { Fabricate(:chat_thread, channel: channel_1) }

    it "shows no preview" do
      chat_page.visit_channel(channel_1)

      expect(channel_page.messages).to have_message(id: message_1.id)
      expect(channel_page).to have_no_thread_indicator(message_1)
    end
  end

  context "when message has thread with replies" do
    fab!(:thread_1) { Fabricate(:chat_thread, channel: channel_1, original_message: message_1) }
    fab!(:thread_1_message_1) do
      Fabricate(:chat_message, thread: thread_1, in_reply_to: message_1, use_service: true)
    end

    it "shows preview" do
      chat_page.visit_channel(channel_1)

      expect(channel_page.messages).to have_message(id: message_1.id)
      expect(channel_page).to have_thread_indicator(message_1)
    end

    context "when the user of the preview has been deleted" do
      fab!(:thread_1_message_1) do
        Fabricate(:chat_message, thread: thread_1, in_reply_to: message_1, use_service: true)
      end

      before { thread_1_message_1.user.destroy! }

      it "shows a deleted user" do
        chat_page.visit_channel(channel_1)

        expect(channel_page).to have_thread_indicator(message_1)
        expect(channel_page).to have_css(".chat-user-avatar[data-username='deleted']")
      end
    end
  end

  context "when message has thread with deleted original message" do
    fab!(:thread_1) { Fabricate(:chat_thread, channel: channel_1, original_message: message_1) }

    before { trash_message!(message_1, user: message_1.user) }

    it "shows preview" do
      chat_page.visit_channel(channel_1)

      expect(channel_page.messages).to have_message(id: message_1.id, deleted: 1)
      expect(channel_page).to have_no_thread_indicator(message_1)
    end
  end
end

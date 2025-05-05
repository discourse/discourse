# frozen_string_literal: true

RSpec.describe "Reply to message - channel - mobile", type: :system, mobile: true do
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:thread_page) { PageObjects::Pages::ChatThread.new }
  let(:side_panel_page) { PageObjects::Pages::ChatSidePanel.new }

  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:category_channel) }
  fab!(:original_message) do
    Fabricate(
      :chat_message,
      chat_channel: channel_1,
      message: "This is a message to reply to!",
      use_service: true,
    )
  end

  before do
    chat_system_bootstrap
    channel_1.update!(threading_enabled: true)
    channel_1.add(current_user)
    sign_in(current_user)
  end

  context "when the message has not current thread" do
    it "starts a thread" do
      chat_page.visit_channel(channel_1)
      channel_page.reply_to(original_message)

      expect(side_panel_page).to have_open_thread

      text = thread_page.send_message

      expect(thread_page.messages).to have_message(text: text, persisted: true)

      thread_page.back

      expect(channel_page).to have_thread_indicator(original_message)
    end

    context "when reloading after creating thread" do
      it "correctly loads the thread" do
        chat_page.visit_channel(channel_1)
        channel_page.reply_to(original_message)
        thread_page.send_message("reply to message")

        expect(thread_page.messages).to have_message(text: "reply to message")

        refresh

        expect(thread_page.messages).to have_message(text: "reply to message")
      end
    end
  end

  context "when the message has an existing thread" do
    fab!(:message_1) { Fabricate(:chat_message, in_reply_to: original_message, use_service: true) }

    it "replies to the existing thread" do
      chat_page.visit_channel(channel_1)

      expect(channel_page.message_thread_indicator(original_message)).to have_reply_count(1)

      channel_page.message_thread_indicator(original_message).click
      expect(thread_page).to be_open
      thread_page.send_message("reply to message")

      expect(thread_page.messages).to have_message(text: message_1.message)
      expect(thread_page.messages).to have_message(text: "reply to message")

      thread_page.back

      expect(channel_page.message_thread_indicator(original_message)).to have_reply_count(2)
      expect(channel_page.messages).to have_no_message(text: "reply to message")
    end
  end

  context "with threading disabled" do
    before { channel_1.update!(threading_enabled: false) }

    it "makes a reply in the channel" do
      chat_page.visit_channel(channel_1)
      channel_page.reply_to(original_message)

      expect(page).to have_selector(
        ".chat-channel .chat-reply__excerpt",
        text: original_message.excerpt,
      )

      text = channel_page.send_message("this is a test message")
      expect(channel_page.messages).to have_message(text:)
    end
  end
end

# frozen_string_literal: true

RSpec.describe "Reply to message - channel - drawer", type: :system do
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:thread_page) { PageObjects::Pages::ChatThread.new }
  let(:drawer_page) { PageObjects::Pages::ChatDrawer.new }

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
      visit("/")
      chat_page.open_from_header
      drawer_page.open_channel(channel_1)
      channel_page.reply_to(original_message)

      expect(drawer_page).to have_open_thread

      text = thread_page.send_message("reply to message")

      expect(thread_page.messages).to have_message(text:)

      drawer_page.back

      expect(channel_page).to have_thread_indicator(original_message)
    end
  end

  context "when the message has an existing thread" do
    fab!(:message_1) { Fabricate(:chat_message, in_reply_to: original_message, use_service: true) }

    it "replies to the existing thread" do
      visit("/")
      chat_page.open_from_header
      drawer_page.open_channel(channel_1)

      expect(channel_page.message_thread_indicator(original_message)).to have_reply_count(1)

      channel_page.reply_to(original_message)

      expect(drawer_page).to have_open_thread

      thread_page.send_message("reply to message")

      expect(thread_page.messages).to have_message(text: message_1.message)
      expect(thread_page.messages).to have_message(text: "reply to message")

      drawer_page.back

      expect(channel_page.message_thread_indicator(original_message)).to have_reply_count(2)
      expect(channel_page.messages).to have_no_message(text: "reply to message")
    end
  end

  context "with threading disabled" do
    before { channel_1.update!(threading_enabled: false) }

    it "makes a reply in the channel" do
      visit("/")
      chat_page.open_from_header
      drawer_page.open_channel(channel_1)
      channel_page.reply_to(original_message)

      expect(page).to have_selector(
        ".chat-channel .chat-reply__excerpt",
        text: original_message.excerpt,
      )

      channel_page.send_message("reply to message")

      expect(channel_page.messages).to have_message(text: "reply to message")
    end
  end
end

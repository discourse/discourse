# frozen_string_literal: true

RSpec.describe "Reply to message - smoke", type: :system do
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:thread_page) { PageObjects::Pages::ChatThread.new }
  let(:side_panel) { PageObjects::Pages::ChatSidePanel.new }

  fab!(:user_1) { Fabricate(:user) }
  fab!(:user_2) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:category_channel) }
  fab!(:original_message) { Fabricate(:chat_message, chat_channel: channel_1) }

  before do
    chat_system_bootstrap
    channel_1.add(user_1)
    channel_1.add(user_2)
    channel_1.update!(threading_enabled: true)
  end

  context "when two users create a thread on the same message" do
    it "works" do
      sign_in(user_1)
      chat_page.visit_channel(channel_1)
      channel_page.reply_to(original_message)

      using_session(:user_2) do
        sign_in(user_2)
        chat_page.visit_channel(channel_1)
        channel_page.reply_to(original_message)
        expect(side_panel).to have_open_thread(original_message.thread)
      end

      thread_page.send_message("user1reply")

      expect(thread_page.messages).to have_message(text: "user1reply")
      expect(channel_page.message_thread_indicator(original_message)).to have_reply_count(1)

      using_session(:user_2) do |session|
        expect(thread_page.messages).to have_message(text: "user1reply")
        expect(channel_page.message_thread_indicator(original_message)).to have_reply_count(1)

        thread_page.send_message("user2reply")

        expect(thread_page.messages).to have_message(text: "user1reply")
        expect(thread_page.messages).to have_message(text: "user2reply")
        expect(channel_page.message_thread_indicator(original_message)).to have_reply_count(2)

        session.quit
      end

      expect(thread_page.messages).to have_message(text: "user1reply")
      expect(thread_page.messages).to have_message(text: "user2reply")
      expect(channel_page.message_thread_indicator(original_message)).to have_reply_count(2)
    end
  end
end

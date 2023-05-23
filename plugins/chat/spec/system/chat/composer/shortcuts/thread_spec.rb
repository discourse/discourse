# frozen_string_literal: true

RSpec.describe "Chat | composer | shortcuts | thread", type: :system, js: true do
  fab!(:channel_1) { Fabricate(:chat_channel, threading_enabled: true) }
  fab!(:current_user) { Fabricate(:user) }
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:thread_page) { PageObjects::Pages::ChatThread.new }

  before do
    SiteSetting.enable_experimental_chat_threaded_discussions = true
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  describe "ArrowUp" do
    let(:thread_1) { message_1.reload.thread }

    context "when there are editable messages" do
      let(:last_thread_message) { thread_1.replies.last }

      before do
        thread_message_1 = Fabricate(:chat_message, user: current_user, in_reply_to: message_1)
        Fabricate(:chat_message, user: current_user, thread: thread_message_1.reload.thread)
      end

      it "starts editing the last editable message" do
        chat_page.visit_thread(thread_1)

        thread_page.composer.edit_last_message_shortcut

        expect(thread_page.composer_message_details).to have_message(last_thread_message)
        expect(thread_page.composer.value).to eq(last_thread_message.message)
      end
    end

    context "when there are no editable messages" do
      before { Fabricate(:chat_message, in_reply_to: message_1) }

      it "does nothing" do
        chat_page.visit_thread(thread_1)

        thread_page.composer.edit_last_message_shortcut

        expect(thread_page.composer_message_details).to have_no_message
        expect(thread_page.composer.value).to be_blank
      end
    end
  end
end

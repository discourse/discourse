# frozen_string_literal: true

RSpec.describe "Chat | composer | thread" do
  fab!(:channel_1) { Fabricate(:chat_channel, threading_enabled: true) }
  fab!(:current_user, :admin)
  fab!(:thread) do
    chat_thread_with_replies(
      channel: channel_1,
      original_message_user: current_user,
      reply_users: [current_user],
      link_replies: true,
    )
  end

  let(:reply) { thread.last_message }
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:thread_page) { PageObjects::Pages::ChatThread.new }
  let(:cdp) { PageObjects::CDP.new }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  describe "edit message" do
    it "cancels edits with Escape or close and applies submitted edits offline" do
      chat_page.visit_thread(thread)
      thread_page.edit_message(reply)

      expect(thread_page.composer).to be_editing_message(reply)

      thread_page.composer.cancel_shortcut

      expect(thread_page.composer).to be_editing_no_message

      thread_page.edit_message(reply)
      expect(thread_page.composer).to be_editing_message(reply)
      thread_page.composer.cancel_editing

      expect(thread_page.composer).to be_editing_no_message

      cdp.with_network_disconnected do
        thread_page.edit_message(reply, "instant")

        expect(thread_page.messages).to have_message(
          text: reply.message + " instant",
          persisted: false,
        )
      end
    end
  end
end

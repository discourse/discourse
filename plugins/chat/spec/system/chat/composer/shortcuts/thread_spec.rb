# frozen_string_literal: true

RSpec.describe "Chat | composer | shortcuts | thread" do
  fab!(:channel_1) { Fabricate(:chat_channel, threading_enabled: true) }
  fab!(:current_user, :admin)
  fab!(:thread_1) { Fabricate(:chat_thread, channel: channel_1) }
  fab!(:reply) do
    Fabricate(
      :chat_message,
      chat_channel: channel_1,
      user: current_user,
      in_reply_to: thread_1.original_message,
      thread: thread_1,
    )
  end

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:thread_page) { PageObjects::Pages::ChatThread.new }
  let(:side_panel_page) { PageObjects::Pages::ChatSidePanel.new }
  let(:cdp) { PageObjects::CDP.new }

  before do
    chat_system_bootstrap
    channel_1.update_last_message_id!
    channel_1.add(thread_1.original_message_user).update!(
      last_read_message: thread_1.original_message,
    )
    channel_1.add(current_user)
    thread_1.update_last_message_id!
    thread_1.update!(replies_count: 1)
    thread_1.add(current_user).update!(last_read_message: reply)
    sign_in(current_user)
  end

  describe "Escape" do
    it "closes the thread panel" do
      chat_page.visit_thread(thread_1)

      page.send_keys(:escape)

      expect(side_panel_page).to have_no_open_thread
    end
  end

  describe "ArrowUp" do
    context "when there are editable messages" do
      fab!(:last_thread_message) do
        Fabricate(:chat_message, chat_channel: channel_1, user: current_user, thread: thread_1)
      end

      before do
        thread_1.update_last_message_id!
        thread_1.update!(replies_count: 2)
        thread_1.membership_for(current_user).update!(last_read_message: last_thread_message)
      end

      it "starts editing the last editable message" do
        chat_page.visit_thread(thread_1)

        thread_page.composer.edit_last_message_shortcut

        expect(thread_page.composer_message_details).to have_message(id: last_thread_message.id)
        expect(thread_page.composer.value).to eq(last_thread_message.message)
      end
    end

    context "when last message is staged" do
      it "does not edit a message" do
        chat_page.visit_thread(thread_1)

        cdp.with_network_disconnected do
          thread_page.send_message
          thread_page.composer.edit_last_message_shortcut

          expect(thread_page.composer.message_details).to have_no_message
        end
      end
    end

    context "when last message is deleted" do
      before do
        reply.trash!
        thread_1.update_last_message_id!
        thread_1.update!(replies_count: 0)
      end

      it "does not edit a message" do
        chat_page.visit_thread(thread_1)

        thread_page.composer.edit_last_message_shortcut

        expect(thread_page.composer.message_details).to have_no_message
      end
    end
  end
end

# frozen_string_literal: true

RSpec.describe "Deleted message", type: :system do
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:sidebar_component) { PageObjects::Components::NavigationMenu::Sidebar.new }

  fab!(:current_user) { Fabricate(:admin) }
  fab!(:channel_1) { Fabricate(:category_channel) }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  context "when deleting a message" do
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }

    it "shows as deleted" do
      chat_page.visit_channel(channel_1)

      channel_page.messages.delete(message_1)

      expect(channel_page.messages).to have_deleted_message(message_1, count: 1)
    end

    it "does not error when coming back to the channel from another channel" do
      message = Fabricate(:chat_message, chat_channel: channel_1)
      channel_2 = Fabricate(:category_channel, name: "other channel")
      channel_2.add(current_user)
      channel_1
        .user_chat_channel_memberships
        .find_by(user: current_user)
        .update!(last_read_message_id: message.id)
      chat_page.visit_channel(channel_1)
      channel_page.messages.delete(message)
      expect(channel_page.messages).to have_deleted_message(message, count: 1)
      sidebar_component.click_link(channel_2.name)
      expect(channel_page).to have_no_loading_skeleton

      sidebar_component.click_link(channel_1.name)
      expect(channel_page.messages).to have_deleted_message(message, count: 1)
    end

    context "when the current user is not admin" do
      fab!(:current_user) { Fabricate(:user) }

      it "does not error when coming back to the channel from another channel" do
        message = Fabricate(:chat_message, chat_channel: channel_1)
        channel_2 = Fabricate(:category_channel, name: "other channel")
        channel_2.add(current_user)
        channel_1
          .user_chat_channel_memberships
          .find_by(user: current_user)
          .update!(last_read_message_id: message.id)
        chat_page.visit_channel(channel_1)
        sidebar_component.click_link(channel_2.name)

        other_user = Fabricate(:admin)
        chat_system_user_bootstrap(user: other_user, channel: channel_1)

        using_session(:tab_2) do
          sign_in(other_user)
          chat_page.visit_channel(channel_1)
          channel_page.messages.delete(message)
        end

        sidebar_component.click_link(channel_1.name)
        expect(channel_page.messages).to have_no_message(id: message.id)
      end
    end
  end

  context "when deleting multiple messages" do
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }
    fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel_1) }
    fab!(:message_3) { Fabricate(:chat_message, chat_channel: channel_1) }
    fab!(:message_4) { Fabricate(:chat_message, chat_channel: channel_1) }
    fab!(:message_5) { Fabricate(:chat_message, chat_channel: channel_1) }
    fab!(:message_6) { Fabricate(:chat_message, chat_channel: channel_1) }

    it "allows user to bulk delete" do
      chat_page.visit_channel(channel_1)

      channel_page.messages.select(message_2)
      channel_page.messages.select(message_4)
      channel_page.messages.select(message_6)
      channel_page.selection_management.delete
      click_button(I18n.t("js.delete"))

      expect(channel_page.messages).to have_deleted_messages(message_2, message_4, message_6)
    end

    it "groups them" do
      chat_page.visit_channel(channel_1)

      trash_message!(message_1)
      trash_message!(message_3)
      trash_message!(message_4)
      trash_message!(message_6)

      expect(channel_page.messages).to have_deleted_messages(message_1, message_6)
      expect(channel_page.messages).to have_deleted_message(message_4, count: 2)
      expect(channel_page.messages).to have_no_message(id: message_3.id)
    end
  end

  context "when bulk deleting messages across the channel and a thread" do
    let(:side_panel) { PageObjects::Pages::ChatSidePanel.new }
    let(:open_thread) { PageObjects::Pages::ChatThread.new }

    fab!(:other_user) { Fabricate(:user) }

    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1, user: other_user) }
    fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel_1, user: other_user) }
    fab!(:message_3) { Fabricate(:chat_message, chat_channel: channel_1, user: other_user) }
    fab!(:thread_1) { Fabricate(:chat_thread, channel: channel_1, original_message: message_3) }

    fab!(:message_4) do
      Fabricate(
        :chat_message,
        in_reply_to_id: message_3.id,
        chat_channel: channel_1,
        user: other_user,
        thread_id: thread_1.id,
      )
    end
    fab!(:message_5) do
      Fabricate(
        :chat_message,
        in_reply_to_id: message_3.id,
        chat_channel: channel_1,
        user: other_user,
        thread_id: thread_1.id,
      )
    end

    before do
      channel_1.update!(threading_enabled: true)
      chat_system_user_bootstrap(user: other_user, channel: channel_1)
      Chat::Thread.update_counts
      thread_1.add(current_user)
    end

    it "hides the deleted messages" do
      chat_page.visit_channel(channel_1)

      channel_page.message_thread_indicator(message_3).click
      expect(side_panel).to have_open_thread(message_3.thread)

      expect(channel_page.messages).to have_message(id: message_2.id)
      expect(channel_page.messages).to have_message(id: message_1.id)
      expect(open_thread.messages).to have_message(thread_id: thread_1.id, id: message_4.id)
      expect(open_thread.messages).to have_message(thread_id: thread_1.id, id: message_5.id)

      open_thread.send_message

      Chat::Publisher.publish_bulk_delete!(
        channel_1,
        [message_1.id, message_2.id, message_4.id, message_5.id].flatten,
      )

      expect(channel_page.messages).to have_deleted_message(message_2, count: 2)
      expect(open_thread.messages).to have_deleted_message(message_5, count: 2)
      expect(open_thread.messages).to have_no_message(thread_id: thread_1.id, id: message_4.id)
      expect(channel_page.messages).to have_no_message(id: message_1.id)
    end
  end
end

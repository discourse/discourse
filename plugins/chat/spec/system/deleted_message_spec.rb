# frozen_string_literal: true

RSpec.describe "Deleted message", type: :system, js: true do
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }

  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:category_channel) }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  context "when deleting a message" do
    it "shows as deleted" do
      chat_page.visit_channel(channel_1)
      channel_page.send_message("aaaaaaaaaaaaaaaaaaaa")
      expect(page).to have_no_css(".chat-message-staged")
      last_message = find(".chat-message-container:last-child")
      channel_page.delete_message(OpenStruct.new(id: last_message["data-id"]))

      expect(page).to have_content(I18n.t("js.chat.deleted"))
    end
  end

  context "when bulk deleting messages across the channel and a thread" do
    let(:side_panel) { PageObjects::Pages::ChatSidePanel.new }
    let(:open_thread) { PageObjects::Pages::ChatThread.new }

    fab!(:other_user) { Fabricate(:user) }
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1, user: other_user) }
    fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel_1, user: other_user) }
    fab!(:message_3) { Fabricate(:chat_message, chat_channel: channel_1, user: other_user) }

    fab!(:thread) { Fabricate(:chat_thread, channel: channel_1) }
    fab!(:message_4) do
      Fabricate(:chat_message, chat_channel: channel_1, user: other_user, thread: thread)
    end
    fab!(:message_5) do
      Fabricate(:chat_message, chat_channel: channel_1, user: other_user, thread: thread)
    end

    before do
      channel_1.update!(threading_enabled: true)
      SiteSetting.enable_experimental_chat_threaded_discussions = true
      chat_system_user_bootstrap(user: other_user, channel: channel_1)
    end

    it "hides the deleted messages" do
      chat_page.visit_channel(channel_1)
      channel_page.message_thread_indicator(thread.original_message).click
      expect(side_panel).to have_open_thread(thread)

      expect(channel_page).to have_message(id: message_1.id)
      expect(channel_page).to have_message(id: message_2.id)
      expect(open_thread).to have_message(thread.id, id: message_4.id)
      expect(open_thread).to have_message(thread.id, id: message_5.id)

      Chat::Publisher.publish_bulk_delete!(
        channel_1,
        [message_1.id, message_2.id, message_4.id, message_5.id].flatten,
      )

      expect(channel_page).to have_no_message(id: message_1.id)
      expect(channel_page).to have_no_message(id: message_2.id)
      expect(open_thread).to have_no_message(thread.id, id: message_4.id)
      expect(open_thread).to have_no_message(thread.id, id: message_5.id)
    end
  end
end

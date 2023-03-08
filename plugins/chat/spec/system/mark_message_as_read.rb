# frozen_string_literal: true

RSpec.describe "Mark message as read", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:chat_channel) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:membership) { Chat::ChatChannelMembershipManager.new(channel_1).find_for_user(current_user) }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    membership.update!(last_read_message_id: first_unread.id)
    25.times { |i| Fabricate(:chat_message, chat_channel: channel_1) }
  end

  context "when the full message is not visible" do
    fab!(:first_unread) { Fabricate(:chat_message, chat_channel: channel_1) }

    it "doesn’t mark it as read" do
      sign_in(current_user)
      before_last_message = Fabricate(:chat_message, chat_channel: channel_1)
      last_message = Fabricate(:chat_message, chat_channel: channel_1)
      chat_page.visit_channel(channel_1)

      page.execute_script("document.querySelector('.chat-messages-scroll').scrollTo(0, -5)")

      try_until_success(timeout: 5) do
        membership.reload.last_read_message_id = before_last_message.id
      end
    end
  end

  context "when the full message is visible" do
    fab!(:first_unread) { Fabricate(:chat_message, chat_channel: channel_1) }

    it "marks it as read" do
      sign_in(current_user)
      last_message = Fabricate(:chat_message, chat_channel: channel_1)
      chat_page.visit_channel(channel_1)

      page.execute_script("document.querySelector('.chat-messages-scroll').scrollTo(0, 0)")

      try_until_success(timeout: 5) { membership.reload.last_read_message_id = last_message.id }
    end
  end
end

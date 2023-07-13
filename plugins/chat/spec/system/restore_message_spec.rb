# frozen_string_literal: true

RSpec.describe "Restore message", type: :system do
  fab!(:admin_user) { Fabricate(:admin) }
  fab!(:regular_user) { Fabricate(:user) }
  fab!(:another_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:category_channel) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:chat_channel_page) { PageObjects::Pages::ChatChannel.new }

  before do
    chat_system_bootstrap
    channel_1.add(admin_user)
    channel_1.add(regular_user)
    channel_1.add(another_user)
  end

  context "when user deletes its own message" do
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1, user: regular_user) }

    it "can be restored by the owner" do
      sign_in(regular_user)
      chat_page.visit_channel(channel_1)

      chat_channel_page.delete_message(message_1)

      expect(chat_channel_page.messages).to have_deleted_message(message_1, count: 1)
      expect(chat_channel_page.messages).to have_action("restore", id: message_1.id)
    end

    it "can't be restored by another user" do
      using_session(:another_user) do
        sign_in(another_user)
        chat_page.visit_channel(channel_1)
      end

      using_session(:regular_user) do |session|
        sign_in(regular_user)
        chat_page.visit_channel(channel_1)
        chat_channel_page.delete_message(message_1)
        session.quit
      end

      using_session(:another_user) do |session|
        expect(chat_channel_page.messages).to have_no_message(id: message_1.id)
        session.quit
      end
    end
  end

  context "when staff deletes user message" do
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1, user: regular_user) }

    it "can't be restored by owner" do
      using_session(:regular_user) do
        sign_in(regular_user)
        chat_page.visit_channel(channel_1)
      end

      using_session(:admin_user) do |session|
        sign_in(admin_user)
        chat_page.visit_channel(channel_1)
        chat_channel_page.delete_message(message_1)
        session.quit
      end

      using_session(:regular_user) do |session|
        expect(chat_channel_page.messages).to have_deleted_message(message_1, count: 1)
        chat_channel_page.messages.expand(id: message_1.id)
        expect(chat_channel_page.messages).to have_no_action("restore", id: message_1.id)
        session.quit
      end
    end
  end
end

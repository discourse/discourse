# frozen_string_literal: true

RSpec.describe "Message user info", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:category_channel) }

  let(:chat_page) { PageObjects::Pages::Chat.new }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  context "with one message" do
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }

    it "shows user info on the message" do
      chat_page.visit_channel(channel_1)

      expect(page.find("[data-id='#{message_1.id}']")).to have_css(".chat-message-avatar")
    end
  end

  context "with two messages from the same user" do
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1, user: current_user) }
    fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel_1, user: current_user) }

    it "shows user info only on first message" do
      chat_page.visit_channel(channel_1)

      expect(page.find("[data-id='#{message_1.id}']")).to have_css(".chat-message-avatar")
      expect(page.find("[data-id='#{message_2.id}']")).to have_no_css(".chat-message-avatar")
    end
  end

  context "with a deleted previous message" do
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1, user: current_user) }
    fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel_1, user: current_user) }

    it "shows user info only on second message" do
      message_1.trash!
      chat_page.visit_channel(channel_1)

      expect(page.find("[data-id='#{message_2.id}']")).to have_css(".chat-message-avatar")
    end
  end

  context "with messages from a webhook" do
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }
    fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel_1) }

    it "shows user info only on boths messages" do
      Fabricate(:chat_webhook_event, chat_message: message_1)
      Fabricate(:chat_webhook_event, chat_message: message_2)
      chat_page.visit_channel(channel_1)

      expect(page.find("[data-id='#{message_1.id}']")).to have_css(".chat-message-avatar")
      expect(page.find("[data-id='#{message_2.id}']")).to have_css(".chat-message-avatar")
    end
  end

  context "with large time difference between messages" do
    fab!(:message_1) do
      Fabricate(:chat_message, chat_channel: channel_1, user: current_user, created_at: 1.days.ago)
    end
    fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel_1, user: current_user) }

    it "shows user info on both messages" do
      chat_page.visit_channel(channel_1)

      expect(page.find("[data-id='#{message_1.id}']")).to have_css(".chat-message-avatar")
      expect(page.find("[data-id='#{message_2.id}']")).to have_css(".chat-message-avatar")
    end
  end

  context "when replying to own previous message" do
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1, user: current_user) }
    fab!(:message_2) do
      Fabricate(:chat_message, in_reply_to: message_1, user: current_user, chat_channel: channel_1)
    end

    it "shows user info on first message only" do
      chat_page.visit_channel(channel_1)

      expect(page.find("[data-id='#{message_1.id}']")).to have_css(".chat-message-avatar")
      expect(page.find("[data-id='#{message_2.id}']")).to have_no_css(".chat-message-avatar")
    end
  end

  context "when replying to another user previous message and previous message is yours" do
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }
    fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel_1, user: current_user) }
    fab!(:message_3) do
      Fabricate(:chat_message, in_reply_to: message_1, user: current_user, chat_channel: channel_1)
    end

    it "shows user info on each message" do
      chat_page.visit_channel(channel_1)

      expect(page.find("[data-id='#{message_1.id}']")).to have_css(".chat-message-avatar")
      expect(page.find("[data-id='#{message_2.id}']")).to have_css(".chat-message-avatar")
      expect(page.find("[data-id='#{message_3.id}']")).to have_css(".chat-message-avatar")
    end
  end
end

# frozen_string_literal: true

RSpec.describe "Sticky date", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:category_channel) }

  let(:chat_page) { PageObjects::Pages::Chat.new }

  before do
    chat_system_bootstrap
    sign_in(current_user)
  end

  context "when previous message is from a different user" do
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }
    fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel_1) }

    it "shows user info on the message" do
      chat_page.visit_channel(channel_1)

      expect(page.find("[data-id='#{message_2.id}']")).to have_css(".chat-message-avatar")
    end
  end

  context "when previous message is from the same user" do
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1, user: current_user) }
    fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel_1, user: current_user) }

    it "doesn’t show user info on the message" do
      chat_page.visit_channel(channel_1)

      expect(page.find("[data-id='#{message_2.id}']")).to have_no_css(".chat-message-avatar")
    end

    context "when previous message is old" do
      fab!(:message_1) do
        Fabricate(
          :chat_message,
          chat_channel: channel_1,
          user: current_user,
          created_at: DateTime.parse("2018-11-10 17:00"),
        )
      end
      fab!(:message_2) do
        Fabricate(
          :chat_message,
          chat_channel: channel_1,
          user: current_user,
          created_at: DateTime.parse("2018-11-10 17:30"),
        )
      end

      it "shows user info on the message" do
        chat_page.visit_channel(channel_1)

        expect(page.find("[data-id='#{message_2.id}']")).to have_no_css(".chat-message-avatar")
      end
    end
  end
end

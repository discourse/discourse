# frozen_string_literal: true

RSpec.describe "Reply indicator", type: :system, js: true do
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }

  fab!(:channel_1) { Fabricate(:category_channel) }
  fab!(:current_user) { Fabricate(:admin) }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  context "clicking on a reply indicator of a loaded message" do
    fab!(:replied_to_message) do
      Fabricate(:chat_message, chat_channel: channel_1, created_at: 2.hours.ago)
    end
    fab!(:reply) do
      Fabricate(
        :chat_message,
        chat_channel: channel_1,
        in_reply_to: replied_to_message,
        created_at: 1.minute.ago,
      )
    end

    before do
      10.times { Fabricate(:chat_message, chat_channel: channel_1, created_at: 1.hour.ago) }
    end

    it "highlights the message without refreshing the pane" do
      chat_page.visit_channel(channel_1)

      find("[data-id='#{reply.id}'] .chat-reply").click

      expect(page).to have_no_selector(".chat-skeleton")
      expect(page).to have_selector("[data-id='#{replied_to_message.id}'].highlighted", wait: 0.1)
    end
  end
end

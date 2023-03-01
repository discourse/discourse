# frozen_string_literal: true

RSpec.describe "Sticky date", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:category_channel) }

  let(:chat_page) { PageObjects::Pages::Chat.new }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    20.times { Fabricate(:chat_message, chat_channel: channel_1, created_at: 1.day.ago) }
    20.times { Fabricate(:chat_message, chat_channel: channel_1) }
    sign_in(current_user)
  end

  context "when clicking a link containing a message id" do
    it "highlights the correct message" do
      chat_page.visit_channel(channel_1)

      expect(page.find(".chat-message-separator__text-container.is-pinned")).to have_content(
        "Today",
      )
    end
  end
end

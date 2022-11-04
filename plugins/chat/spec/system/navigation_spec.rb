# frozen_string_literal: true

RSpec.describe "Navigation", type: :system, js: true do
  fab!(:user) { Fabricate(:user) }
  fab!(:category_channel) { Fabricate(:category_channel) }
  fab!(:message) { Fabricate(:chat_message, chat_channel: category_channel) }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
  end

  context "when visiting /chat" do
    before do
      category_channel.add(user)
      sign_in(user)
    end

    it "it opens full page" do
      visit("/chat")

      expect(page).to have_current_path(
        chat.channel_path(category_channel.id, category_channel.slug),
      )
      expect(page).to have_css("html.has-full-page-chat")
      expect(page).to have_css(".chat-message-container[data-id='#{message.id}']")
    end
  end
end

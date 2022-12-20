# frozen_string_literal: true

RSpec.describe "Bookmark message", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:channel) { PageObjects::Pages::ChatChannel.new }
  fab!(:category_channel_1) { Fabricate(:category_channel) }
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: category_channel_1) }

  before do
    chat_system_bootstrap
    category_channel_1.add(current_user)
    sign_in(current_user)
  end

  context "when desktop" do
    it "allows to bookmark a message" do
      chat.visit_channel(category_channel_1)
      channel.bookmark_message(message_1)

      expect(page).to have_css("#bookmark-reminder-modal")

      find("#bookmark-name").fill_in(with: "Check this out later")
      find("#tap_tile_next_month").click

      expect(channel).to have_bookmarked_message(message_1)
    end
  end

  context "when mobile", mobile: true do
    it "allows to bookmark a message" do
      chat.visit_channel(category_channel_1)

      channel.message_by_id(message_1.id).click(delay: 0.5)
      find(".bookmark-btn").click
      expect(page).to have_css("#bookmark-reminder-modal")

      find("#bookmark-name").fill_in(with: "Check this out later")
      find("#tap_tile_next_month").click

      expect(channel).to have_bookmarked_message(message_1)
    end
  end
end

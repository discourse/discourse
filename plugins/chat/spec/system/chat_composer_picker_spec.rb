# frozen_string_literal: true

RSpec.describe "Chat composer picker" do
  fab!(:current_user, :user)
  fab!(:channel_1, :chat_channel)

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }

  before do
    SiteSetting.enable_gifs = true
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  context "when the upcoming change is enabled" do
    before { SiteSetting.enable_composer_picker_and_rich_chat = true }

    it "inserts an emoji from the tabbed picker" do
      chat_page.visit_channel(channel_1)
      find(".chat-composer-button.--emoji").click

      expect(page).to have_css(".composer-picker [role='tab']", count: 2)

      emoji = first(".composer-picker img.emoji[data-emoji]")
      name = emoji["data-emoji"]
      emoji.click

      expect(channel_page.composer).to have_value(":#{name}:")
    end
  end

  context "when the upcoming change is disabled" do
    it "keeps the emoji-only picker" do
      chat_page.visit_channel(channel_1)
      find(".chat-composer-button.--emoji").click

      expect(page).to have_css(".emoji-picker")
      expect(page).to have_no_css(".composer-picker")
    end
  end
end

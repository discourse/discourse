# frozen_string_literal: true

RSpec.describe "Flag message", type: :system do
  fab!(:current_user) { Fabricate(:user) }

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:channel) { PageObjects::Pages::ChatChannel.new }

  before do
    chat_system_bootstrap
    sign_in(current_user)
  end

  context "when category channel" do
    fab!(:category_channel_1) { Fabricate(:category_channel) }
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: category_channel_1) }

    before { category_channel_1.add(current_user) }

    it "allows to flag a message" do
      chat.visit_channel(category_channel_1)
      channel.messages.flag(message_1)

      expect(page).to have_css(".flag-modal")

      choose("radio_spam")
      click_button(I18n.t("js.chat.flagging.action"))

      expect(channel.message_by_id(message_1.id)).to have_css(".chat-message-info__flag")
    end
  end

  context "when direct message channel" do
    fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [current_user]) }
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: dm_channel_1) }

    it "allows to flag a message" do
      chat.visit_channel(dm_channel_1)
      channel.expand_message_actions(message_1)

      expect(page).to have_css("[data-value='flag']")
    end
  end
end

# frozen_string_literal: true

RSpec.describe "Message errors", type: :system do
  fab!(:current_user) { Fabricate(:admin) }
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:max_length) { SiteSetting.chat_maximum_message_length }

  before { chat_system_bootstrap }

  context "when message is too long" do
    fab!(:channel) { Fabricate(:chat_channel) }

    before { channel.add(current_user) }

    it "only shows the error, not the message" do
      sign_in(current_user)
      chat_page.visit_channel(channel)

      channel_page.send_message("atoolongmessage" + "a" * max_length)

      expect(page).to have_content(I18n.t("chat.errors.message_too_long", count: max_length))
      expect(page).to have_no_content("atoolongmessage")
    end
  end
end

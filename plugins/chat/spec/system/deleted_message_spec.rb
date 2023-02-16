# frozen_string_literal: true

RSpec.describe "Deleted message", type: :system, js: true do
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }

  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:category_channel) }
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1, user: current_user) }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  context "when deleting a message" do
    it "shows as deleted" do
      chat_page.visit_channel(channel_1)
      expect(channel_page).to have_no_loading_skeleton

      channel_page.expand_message_actions(message_1)
      find("[data-value='deleteMessage']").click

      expect(page).to have_content(I18n.t("js.chat.deleted"))
    end
  end
end

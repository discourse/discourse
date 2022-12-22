# frozen_string_literal: true

RSpec.describe "Edited message", type: :system, js: true do
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }

  fab!(:current_user) { Fabricate(:user) }
  fab!(:editing_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:category_channel) }
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1, user: editing_user) }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    channel_1.add(editing_user)
    sign_in(current_user)
  end

  context "when editing message" do
    xit "shows as edited for all users" do
      chat_page.visit_channel(channel_1)

      using_session(editing_user.username) do
        sign_in(editing_user)
        chat_page.visit_channel(channel_1)
        channel_page.edit_message(message_1, "a different message")
        expect(page).to have_content(I18n.t("js.chat.edited"))
      end

      expect(page).to have_content(I18n.t("js.chat.edited"))
    end
  end
end

# frozen_string_literal: true

RSpec.describe "Edited message", type: :system do
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }

  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:category_channel) }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  context "when editing message" do
    context "with multiple users in the channel" do
      fab!(:editing_user) { Fabricate(:user) }
      fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1, user: editing_user) }

      before { channel_1.add(editing_user) }

      it "shows as edited for all users" do
        chat_page.visit_channel(channel_1)

        using_session(:user_1) do |session|
          sign_in(editing_user)
          chat_page.visit_channel(channel_1)
          channel_page.edit_message(message_1, "a different message")
          expect(page).to have_content(I18n.t("js.chat.edited"))
          session.quit
        end

        expect(page).to have_content(I18n.t("js.chat.edited"))
      end
    end

    it "runs decorators on the edited message" do
      message_1 = Fabricate(:chat_message, chat_channel: channel_1, user: current_user)
      chat_page.visit_channel(channel_1)

      channel_page.edit_message(message_1, '[date=2025-03-10 timezone="Europe/Paris"]')

      expect(page).to have_css(".cooked-date")
    end
  end
end

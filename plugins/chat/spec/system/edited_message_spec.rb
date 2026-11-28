# frozen_string_literal: true

RSpec.describe "Edited message" do
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }

  fab!(:current_user, :user)
  fab!(:channel_1, :category_channel)

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  context "when editing message" do
    context "with multiple users in the channel" do
      fab!(:editing_user, :user)
      fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1, user: editing_user) }

      before { channel_1.add(editing_user) }

      it "shows as edited for all users" do
        chat_page.visit_channel(channel_1)

        using_session(:user_1) do
          sign_in(editing_user)
          chat_page.visit_channel(channel_1)
          channel_page.edit_message(message_1, "a different message")
          expect(page).to have_content(I18n.t("js.chat.edited"))
        end

        expect(page).to have_content(I18n.t("js.chat.edited"))
      end
    end

    context "for the author" do
      fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1, user: current_user) }

      it "runs decorators on edits and shows the reply indicator when replying to an edited message" do
        chat_page.visit_channel(channel_1)

        channel_page.edit_message(message_1, '[date=2025-03-10 timezone="Europe/Paris"]')

        expect(page).to have_css(".cooked-date")

        edit = message_1.message + "a"
        channel_page.edit_message(message_1, edit)
        expect(channel_page.messages).to have_message(id: message_1.id, text: edit, persisted: true)
        channel_page.reply_to(message_1)

        expect(channel_page.composer.message_details).to be_replying_to(message_1)
      end
    end
  end
end

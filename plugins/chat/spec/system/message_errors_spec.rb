# frozen_string_literal: true

RSpec.describe "Message errors", type: :system do
  context "when message is too long" do
    let(:chat_page) { PageObjects::Pages::Chat.new }
    let(:dialog_page) { PageObjects::Components::Dialog.new }
    let(:max_length) { SiteSetting.chat_maximum_message_length }
    let(:message) { "atoolongmessage" + "a" * max_length }

    fab!(:current_user) { Fabricate(:admin) }
    fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }

    before do
      chat_system_bootstrap
      sign_in(current_user)
      channel.add(current_user)
    end

    context "when in channel" do
      let(:channel_page) { PageObjects::Pages::ChatChannel.new }

      it "shows a dialog with the error and keeps the message in the input" do
        chat_page.visit_channel(channel)

        channel_page.send_message(message)

        expect(dialog_page).to have_content(
          I18n.t("chat.errors.message_too_long", count: max_length),
        )
        expect(channel_page.composer).to have_value(message)
      end
    end

    context "when in thread" do
      fab!(:thread) { Fabricate(:chat_thread, channel: channel) }

      let(:thread_page) { PageObjects::Pages::ChatThread.new }

      before { thread.add(current_user) }

      it "shows a dialog with the error and keeps the message in the input" do
        chat_page.visit_thread(thread)

        thread_page.send_message(message)

        expect(dialog_page).to have_content(
          I18n.t("chat.errors.message_too_long", count: max_length),
        )
        expect(thread_page.composer).to have_value(message)
      end
    end
  end
end

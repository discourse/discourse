# frozen_string_literal: true

RSpec.describe "Dates separators", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:chat_channel) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  context "when today separator is out of screen" do
    before do
      15.times { Fabricate(:chat_message, chat_channel: channel_1, created_at: 1.day.ago) }
      30.times { Fabricate(:chat_message, chat_channel: channel_1) }
    end

    xit "shows it as a sticky date" do
      chat_page.visit_channel(channel_1)

      expect(page.find(".chat-message-separator__text-container.is-pinned")).to have_content(
        I18n.t("js.chat.chat_message_separator.today"),
      )
      expect(page).to have_css(
        ".chat-message-separator__text-container:not(.is-pinned)",
        visible: :hidden,
        text:
          "#{I18n.t("js.chat.chat_message_separator.yesterday")} - #{I18n.t("js.chat.last_visit")}",
      )
    end
  end

  context "when receiving messages on a different channel" do
    fab!(:channel_2) { Fabricate(:chat_channel) }
    fab!(:user_1) { Fabricate(:user) }

    before do
      channel_2.add(current_user)
      channel_1.add(user_1)
    end

    it "doesn't impact the last visit separator" do
      chat_page.visit_channel(channel_1)
      channel_page.send_message("message1")
      chat_page.visit_channel(channel_2)

      using_session(:user_1) do |session|
        sign_in(user_1)
        chat_page.visit_channel(channel_1)
        channel_page.send_message("message2")
        session.quit
      end

      chat_page.visit_channel(channel_1)

      expect(page).to have_css(
        ".chat-message-separator__text-container",
        text: I18n.t("js.chat.last_visit"),
      )
    end
  end
end

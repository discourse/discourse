# frozen_string_literal: true

RSpec.describe "Sticky date", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:category_channel) }

  let(:chat_page) { PageObjects::Pages::Chat.new }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    20.times { Fabricate(:chat_message, chat_channel: channel_1, created_at: 1.day.ago) }
    25.times { Fabricate(:chat_message, chat_channel: channel_1) }
    sign_in(current_user)
  end

  context "when today separator is out of screen" do
    it "shows it as a sticky date" do
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
end

# frozen_string_literal: true

RSpec.describe "Dates separators" do
  fab!(:current_user, :user)
  fab!(:channel_1, :chat_channel)

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:sidebar_page) { PageObjects::Pages::ChatSidebar.new }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  it "pins Today's date on opening the channel at the live edge",
     time: Time.zone.parse("2026-05-01 12:00:00") do
    Fabricate(:chat_message, chat_channel: channel_1, user: current_user, created_at: 2.days.ago)
    # Pinning needs a day taller than the scrollport, not a full page of messages.
    today_message =
      Fabricate(
        :chat_message,
        chat_channel: channel_1,
        user: current_user,
        message: "Line\n\n" * 80,
      )

    chat_page.visit_channel(channel_1)

    today = ".chat-message-separator-date[data-id='#{today_message.id}']"
    expect(page).to have_css(
      "#{today} .chat-message-separator__text-container.is-pinned",
      text: I18n.t("js.chat.chat_message_separator.today"),
    )
    expect(page).to have_css(
      ".chat-message-separator-date.with-last-visit .chat-message-separator__text-container:not(.is-pinned)",
      text: I18n.t("js.chat.last_visit"),
    )

    scroller = find(".chat-channel .chat-messages-scroller")
    scroller.scroll_to(0, -10_000)
    expect(page).to have_css(
      ".chat-message-separator-date.with-last-visit .chat-message-separator__text-container:not(.is-pinned)",
      text: I18n.t("js.chat.last_visit"),
    )
    expect(page).to have_css(
      "#{today} .chat-message-separator__text-container:not(.is-pinned)",
      text: I18n.t("js.chat.chat_message_separator.today"),
    )

    scroller.hover
    page.driver.with_playwright_page { |browser| browser.mouse.wheel(0, 10_000) }

    expect(page).to have_css(
      "#{today} .chat-message-separator__text-container.is-pinned",
      text: I18n.t("js.chat.chat_message_separator.today"),
    )
    expect(page).to have_css(
      ".chat-message-separator-date.with-last-visit .chat-message-separator__text-container:not(.is-pinned)",
      text: I18n.t("js.chat.last_visit"),
    )
  end

  context "when receiving messages on a different channel" do
    fab!(:channel_2, :chat_channel)
    fab!(:user_1, :user)

    before do
      channel_2.add(current_user)
      channel_1.add(user_1)
    end

    it "doesn't impact the last visit separator" do
      chat_page.visit_channel(channel_1)
      channel_page.send_message("message1")
      sidebar_page.open_channel(channel_2)

      using_session(:user_1) do
        sign_in(user_1)
        chat_page.visit_channel(channel_1)
        channel_page.send_message("message2")
      end

      sidebar_page.open_channel(channel_1)

      expect(page).to have_css(
        ".chat-message-separator__text-container",
        text: I18n.t("js.chat.last_visit"),
      )
    end
  end
end

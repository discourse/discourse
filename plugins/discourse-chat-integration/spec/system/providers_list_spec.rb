# frozen_string_literal: true

RSpec.describe "Chat integration providers list" do
  fab!(:admin)

  before do
    SiteSetting.chat_integration_enabled = true
    SiteSetting.chat_integration_telegram_enabled = true
    SiteSetting.chat_integration_discord_enabled = true
    sign_in(admin)
  end

  it "lists enabled providers and links each one to its channels page" do
    visit("/admin/plugins/discourse-chat-integration/providers")

    expect(page).to have_css(
      ".chat-integration-providers__row[data-provider='telegram']",
      text: I18n.t("js.chat_integration.provider.telegram.title"),
    )
    expect(page).to have_css(
      ".chat-integration-providers__row[data-provider='discord']",
      text: I18n.t("js.chat_integration.provider.discord.title"),
    )

    find(
      ".chat-integration-providers__row[data-provider='discord'] .chat-integration-providers__edit",
    ).click

    expect(page).to have_current_path("/admin/plugins/discourse-chat-integration/providers/discord")
    expect(page).to have_css(".back-button", text: I18n.t("js.chat_integration.back_to_providers"))
    expect(page).to have_css(
      ".d-page-subheader__title",
      text: I18n.t("js.chat_integration.provider.discord.title"),
    )
  end
end

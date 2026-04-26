# frozen_string_literal: true

RSpec.describe "Provider navigation" do
  fab!(:admin)

  before do
    SiteSetting.chat_integration_enabled = true
    SiteSetting.chat_integration_telegram_enabled = true
    SiteSetting.chat_integration_discord_enabled = true
    sign_in(admin)
  end

  it "only marks the current provider's nav pill as active" do
    visit("/admin/plugins/discourse-chat-integration/providers/telegram")

    expect(page).to have_css(
      ".admin-nav-submenu li.active",
      count: 1,
      text: I18n.t("js.chat_integration.provider.telegram.title"),
    )
    expect(page).to have_css(
      ".admin-nav-submenu li:not(.active)",
      count: 1,
      text: I18n.t("js.chat_integration.provider.discord.title"),
    )
  end
end

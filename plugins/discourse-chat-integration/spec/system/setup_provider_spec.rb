# frozen_string_literal: true

RSpec.describe "Chat integration setup provider" do
  fab!(:admin)

  let(:setup_page) { PageObjects::Pages::ChatIntegrationSetupProvider.new }

  before do
    enable_current_plugin
    SiteSetting.chat_integration_enabled = true
    SiteSetting.chat_integration_discord_enabled = true
    SiteSetting.chat_integration_slack_enabled = false
    SiteSetting.chat_integration_telegram_enabled = false
    SiteSetting.chat_integration_slack_access_token = ""
    SiteSetting.chat_integration_telegram_access_token = ""
    sign_in(admin)
  end

  def open_setup_modal_for_provider(provider_title)
    visit "/admin/plugins/discourse-chat-integration/providers/discord"

    find(".chat-integration-add-provider-trigger").click

    within("#d-menu-portals") { find("button", text: provider_title).click }
  end

  it "sets up Slack from the modal when the token is valid" do
    stub_request(:post, "https://slack.com/api/auth.test").to_return(
      body: { ok: true }.to_json,
      headers: {
        "Content-Type" => "application/json",
      },
    )

    open_setup_modal_for_provider(I18n.t("js.chat_integration.provider.slack.title"))

    expect(page).to have_css("#chat-integration-setup-provider-modal")

    setup_page.fill_slack_access_token("xoxb-system-test")
    setup_page.submit

    expect(page).to have_current_path(
      %r{/admin/plugins/discourse-chat-integration/providers/slack},
      wait: Capybara.default_max_wait_time * 2,
    )
    expect(SiteSetting.chat_integration_slack_enabled).to eq(true)
  end

  it "shows a field error on the webhook field when the URL is invalid" do
    open_setup_modal_for_provider(I18n.t("js.chat_integration.provider.slack.title"))

    setup_page.fill_slack_webhook_url("https://example.com/not-slack")
    setup_page.submit

    expect(setup_page.has_field_error?("chat_integration_slack_outbound_webhook_url")).to eq(true)
    expect(page).to have_css("#chat-integration-setup-provider-modal")
  end

  it "shows a field error in the Slack modal when the token is rejected" do
    stub_request(:post, "https://slack.com/api/auth.test").to_return(
      body: { ok: false, error: "invalid_auth" }.to_json,
      headers: {
        "Content-Type" => "application/json",
      },
    )

    open_setup_modal_for_provider(I18n.t("js.chat_integration.provider.slack.title"))

    setup_page.fill_slack_access_token("xoxb-bad")
    setup_page.submit

    expect(setup_page.has_field_error?("chat_integration_slack_access_token")).to eq(true)
    expect(page).to have_css("#chat-integration-setup-provider-modal")
  end

  it "sets up Telegram from the modal when setWebhook succeeds" do
    stub_request(:post, %r{https://api\.telegram\.org/botsystok/setWebhook}).to_return(
      body: { ok: true }.to_json,
      headers: {
        "Content-Type" => "application/json",
      },
    )

    open_setup_modal_for_provider(I18n.t("js.chat_integration.provider.telegram.title"))

    expect(page).to have_css("#chat-integration-setup-provider-modal")

    setup_page.fill_telegram_access_token("systok")
    setup_page.submit

    expect(page).to have_current_path(
      %r{/admin/plugins/discourse-chat-integration/providers/telegram},
      wait: Capybara.default_max_wait_time * 2,
    )
    expect(SiteSetting.chat_integration_telegram_enabled).to eq(true)
  end

  it "shows a field error in the Telegram modal when setWebhook fails" do
    stub_request(:post, %r{https://api\.telegram\.org/botbadsys/setWebhook}).to_return(
      body: { ok: false }.to_json,
      headers: {
        "Content-Type" => "application/json",
      },
    )

    open_setup_modal_for_provider(I18n.t("js.chat_integration.provider.telegram.title"))

    setup_page.fill_telegram_access_token("badsys")
    setup_page.submit

    expect(setup_page.has_field_error?("chat_integration_telegram_access_token")).to eq(true)
    expect(page).to have_css("#chat-integration-setup-provider-modal")
  end
end

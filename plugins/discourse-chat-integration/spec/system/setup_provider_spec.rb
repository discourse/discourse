# frozen_string_literal: true

RSpec.describe "Chat integration setup provider" do
  fab!(:admin)

  let(:setup_page) { PageObjects::Pages::ChatIntegrationSetupProvider.new }
  let(:modal) { PageObjects::Modals::Base.new }
  let(:dialog) { PageObjects::Components::Dialog.new }

  before do
    enable_current_plugin
    SiteSetting.chat_integration_enabled = true
    sign_in(admin)
  end

  def setup_provider_from_menu(provider_name)
    visit "/admin/plugins/discourse-chat-integration/providers"

    setup_page.add_provider_menu.expand
    setup_page
      .add_provider_menu
      .option(".chat-integration-add-provider-button.--#{provider_name.downcase}")
      .click
  end

  describe "quick setup when no providers are enabled" do
    it "sets up Discord" do
      visit "/admin/plugins/discourse-chat-integration/providers"
      setup_page.setup_popular_provider("discord")

      expect(dialog).to be_open
      expect(dialog).to have_content(
        I18n.t("js.chat_integration.confirm_setup_provider", provider: "Discord"),
      )
      dialog.click_yes

      expect(page).to have_content(
        I18n.t("js.chat_integration.setup_provider_modal.success", provider: "Discord"),
      )
      expect(page).to have_current_path(
        %r{/admin/plugins/discourse-chat-integration/providers/discord},
      )
      expect(SiteSetting.chat_integration_discord_enabled).to eq(true)
    end
  end

  describe "adding more providers when at least one provider is enabled" do
    before { SiteSetting.chat_integration_teams_enabled = true }
    it "sets up Discord" do
      setup_provider_from_menu("discord")

      expect(dialog).to be_open
      expect(dialog).to have_content(
        I18n.t("js.chat_integration.confirm_setup_provider", provider: "Discord"),
      )
      dialog.click_yes

      expect(page).to have_content(
        I18n.t("js.chat_integration.setup_provider_modal.success", provider: "Discord"),
      )
      expect(page).to have_current_path(
        %r{/admin/plugins/discourse-chat-integration/providers/discord},
      )
      expect(SiteSetting.chat_integration_discord_enabled).to eq(true)
    end

    describe "providers which use the setup modal to fill additional fields" do
      it "sets up Slack from the modal when the token is valid" do
        stub_request(:post, "https://slack.com/api/auth.test").to_return(
          body: { ok: true }.to_json,
          headers: {
            "Content-Type" => "application/json",
          },
        )

        setup_provider_from_menu("slack")
        expect(modal).to be_open

        setup_page.fill_slack_access_token("xoxb-system-test")
        setup_page.submit

        expect(page).to have_content(
          I18n.t("js.chat_integration.setup_provider_modal.success", provider: "Slack"),
        )
        expect(page).to have_current_path(
          %r{/admin/plugins/discourse-chat-integration/providers/slack},
        )
        expect(SiteSetting.chat_integration_slack_enabled).to eq(true)
      end

      it "shows a field error on the webhook field when the URL is invalid" do
        setup_provider_from_menu("slack")
        expect(modal).to be_open

        setup_page.fill_slack_webhook_url("https://example.com/not-slack")
        setup_page.submit

        expect(setup_page.has_field_error?("chat_integration_slack_outbound_webhook_url")).to eq(
          true,
        )
      end

      it "shows a field error in the Slack modal when the token is rejected" do
        stub_request(:post, "https://slack.com/api/auth.test").to_return(
          body: { ok: false, error: "invalid_auth" }.to_json,
          headers: {
            "Content-Type" => "application/json",
          },
        )

        setup_provider_from_menu("slack")
        expect(modal).to be_open

        setup_page.fill_slack_access_token("xoxb-bad")
        setup_page.submit

        expect(setup_page.has_field_error?("chat_integration_slack_access_token")).to eq(true)
      end

      it "sets up Telegram from the modal when setWebhook succeeds" do
        stub_request(:post, %r{https://api\.telegram\.org/botsystok/setWebhook}).to_return(
          body: { ok: true }.to_json,
          headers: {
            "Content-Type" => "application/json",
          },
        )

        setup_provider_from_menu("telegram")
        expect(modal).to be_open

        setup_page.fill_telegram_access_token("systok")
        setup_page.submit

        expect(page).to have_content(
          I18n.t("js.chat_integration.setup_provider_modal.success", provider: "Telegram"),
        )
        expect(page).to have_current_path(
          %r{/admin/plugins/discourse-chat-integration/providers/telegram},
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
        allow(Rails.logger).to receive(:error).and_call_original
        allow(Rails.logger).to receive(:error).with(/\AFailed to setup telegram webhook\./)

        setup_provider_from_menu("telegram")
        expect(modal).to be_open

        setup_page.fill_telegram_access_token("badsys")
        setup_page.submit

        expect(setup_page.has_field_error?("chat_integration_telegram_access_token")).to eq(true)
      end
    end
  end
end

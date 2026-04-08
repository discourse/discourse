# frozen_string_literal: true

RSpec.describe DiscourseChatIntegration::Provider::TelegramProvider do
  let(:post) { Fabricate(:post) }
  let!(:webhook_stub) do
    stub_request(:post, "https://api.telegram.org/botTOKEN/setWebhook").to_return(
      body: "{\"ok\":true}",
    )
  end

  describe ".trigger_notifications" do
    before do
      SiteSetting.chat_integration_telegram_access_token = "TOKEN"
      SiteSetting.chat_integration_telegram_enabled = true
      SiteSetting.chat_integration_telegram_secret = "shhh"
    end

    let(:chan1) do
      DiscourseChatIntegration::Channel.create!(
        provider: "telegram",
        data: {
          name: "Awesome Channel",
          chat_id: "123",
        },
      )
    end

    it "sends a webhook request" do
      stub1 =
        stub_request(:post, "https://api.telegram.org/botTOKEN/sendMessage").to_return(
          body: "{\"ok\":true}",
        )
      described_class.trigger_notification(post, chan1, nil)
      expect(stub1).to have_been_requested.once
    end

    it "handles errors correctly" do
      stub1 =
        stub_request(:post, "https://api.telegram.org/botTOKEN/sendMessage").to_return(
          body: "{\"ok\":false, \"description\":\"chat not found\"}",
        )
      expect(stub1).to have_been_requested.times(0)
      expect { described_class.trigger_notification(post, chan1, nil) }.to raise_exception(
        DiscourseChatIntegration::ProviderError,
      )
      expect(stub1).to have_been_requested.once
    end
  end

  describe ".get_channel_by_name" do
    it "returns the right channel" do
      expected =
        DiscourseChatIntegration::Channel.create!(
          provider: "telegram",
          data: {
            name: "Awesome Channel",
            chat_id: "123",
          },
        )
      expect(described_class.get_channel_by_name("Awesome Channel")).to eq(expected)
    end
  end

  describe ".setup" do
    fab!(:admin)

    before do
      SiteSetting.chat_integration_telegram_enabled = false
      SiteSetting.chat_integration_telegram_access_token = ""
      SiteSetting.chat_integration_telegram_secret = ""
    end

    it "raises when access token is blank" do
      expect { described_class.setup(admin, {}) }.to raise_error(
        DiscourseChatIntegration::ProviderError,
      ) do |e|
        expect(e.info[:error_key]).to eq(
          "chat_integration.provider.telegram.errors.access_token_required",
        )
      end
    end

    it "persists settings when setWebhook succeeds" do
      stub =
        stub_request(:post, %r{https://api\.telegram\.org/botnewtok/setWebhook}).to_return(
          body: { ok: true }.to_json,
          headers: {
            "Content-Type" => "application/json",
          },
        )

      described_class.setup(admin, { chat_integration_telegram_access_token: "newtok" })

      expect(stub).to have_been_requested.once
      expect(SiteSetting.chat_integration_telegram_access_token).to eq("newtok")
      expect(SiteSetting.chat_integration_telegram_secret).to be_present
      expect(SiteSetting.chat_integration_telegram_enabled).to eq(true)
    end

    it "raises and does not change stored token when setWebhook fails" do
      SiteSetting.chat_integration_telegram_access_token = "unchanged"
      SiteSetting.chat_integration_telegram_secret = "existing-secret"

      stub_request(:post, %r{https://api\.telegram\.org/botbad/setWebhook}).to_return(
        body: { ok: false, description: "Bad Request" }.to_json,
        headers: {
          "Content-Type" => "application/json",
        },
      )

      expect {
        described_class.setup(admin, { chat_integration_telegram_access_token: "bad" })
      }.to raise_error(DiscourseChatIntegration::ProviderError) do |e|
        expect(e.info[:error_key]).to eq(
          "chat_integration.provider.telegram.errors.webhook_setup_failed",
        )
      end

      expect(SiteSetting.chat_integration_telegram_access_token).to eq("unchanged")
      expect(SiteSetting.chat_integration_telegram_secret).to eq("existing-secret")
      expect(SiteSetting.chat_integration_telegram_enabled).to eq(false)
    end
  end
end

# frozen_string_literal: true

require "rails_helper"

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
        ::DiscourseChatIntegration::ProviderError,
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
end

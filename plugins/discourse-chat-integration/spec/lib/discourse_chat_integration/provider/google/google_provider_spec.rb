# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseChatIntegration::Provider::GoogleProvider do
  let(:post) { Fabricate(:post) }

  describe ".trigger_notifications" do
    before { SiteSetting.chat_integration_google_enabled = true }

    let(:chan1) do
      DiscourseChatIntegration::Channel.create!(
        provider: "google",
        data: {
          name: "discourse",
          webhook_url: "https://chat.googleapis.com/v1/abcdefg",
        },
      )
    end

    it "sends a webhook request" do
      stub1 = stub_request(:post, chan1.data["webhook_url"]).to_return(body: "1")
      described_class.trigger_notification(post, chan1, nil)
      expect(stub1).to have_been_requested.once
    end

    it "handles errors correctly" do
      stub1 = stub_request(:post, chan1.data["webhook_url"]).to_return(status: 400, body: "{}")
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
          provider: "google",
          data: {
            name: "discourse",
            webhook_url: "https://chat.googleapis.com/v1/abcdefg",
          },
        )
      expect(described_class.get_channel_by_name("discourse")).to eq(expected)
    end
  end
end

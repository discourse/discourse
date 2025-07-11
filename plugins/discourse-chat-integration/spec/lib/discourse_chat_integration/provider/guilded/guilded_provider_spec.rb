# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseChatIntegration::Provider::GuildedProvider do
  let(:post) { Fabricate(:post) }

  describe ".trigger_notifications" do
    before { SiteSetting.chat_integration_guilded_enabled = true }

    let(:chan1) do
      DiscourseChatIntegration::Channel.create!(
        provider: "guilded",
        data: {
          name: "Awesome Channel",
          webhook_url: "https://media.guilded.gg/webhooks/1234/abcd",
        },
      )
    end

    it "sends a webhook request" do
      stub1 =
        stub_request(:post, "https://media.guilded.gg/webhooks/1234/abcd").to_return(status: 200)
      described_class.trigger_notification(post, chan1, nil)
      expect(stub1).to have_been_requested.once
    end

    it "handles errors correctly" do
      stub1 =
        stub_request(:post, "https://media.guilded.gg/webhooks/1234/abcd").to_return(status: 400)
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
          provider: "guilded",
          data: {
            name: "Awesome Channel",
            webhook_url: "https://media.guilded.gg/webhooks/1234/abcd",
          },
        )
      expect(described_class.get_channel_by_name("Awesome Channel")).to eq(expected)
    end
  end
end

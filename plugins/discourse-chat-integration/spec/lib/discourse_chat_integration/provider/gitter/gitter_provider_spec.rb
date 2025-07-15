# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseChatIntegration::Provider::GitterProvider do
  let(:post) { Fabricate(:post) }

  describe ".trigger_notifications" do
    before { SiteSetting.chat_integration_gitter_enabled = true }

    let(:chan1) do
      DiscourseChatIntegration::Channel.create!(
        provider: "gitter",
        data: {
          name: "gitterHQ/services",
          webhook_url: "https://webhooks.gitter.im/e/a1e2i3o4u5",
        },
      )
    end

    it "sends a webhook request" do
      stub1 = stub_request(:post, chan1.data["webhook_url"]).to_return(body: "OK")
      described_class.trigger_notification(post, chan1, nil)
      expect(stub1).to have_been_requested.once
    end

    it "handles errors correctly" do
      stub1 =
        stub_request(:post, chan1.data["webhook_url"]).to_return(
          status: 404,
          body: "{ \"error\": \"Not Found\"}",
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
          provider: "gitter",
          data: {
            name: "gitterHQ/services",
            webhook_url: "https://webhooks.gitter.im/e/a1e2i3o4u5",
          },
        )
      expect(described_class.get_channel_by_name("gitterHQ/services")).to eq(expected)
    end
  end
end

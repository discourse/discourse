# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseChatIntegration::Provider::FlowdockProvider do
  let(:post) { Fabricate(:post) }

  describe ".trigger_notifications" do
    before { SiteSetting.chat_integration_flowdock_enabled = true }

    let(:chan1) do
      DiscourseChatIntegration::Channel.create!(
        provider: "flowdock",
        data: {
          flow_token: "5d1fe04cf66e078d6a2b579ddb8a465b",
        },
      )
    end

    it "sends a request" do
      stub1 = stub_request(:post, "https://api.flowdock.com/messages").to_return(status: 200)
      described_class.trigger_notification(post, chan1, nil)
      expect(stub1).to have_been_requested.once
    end

    it "handles errors correctly" do
      stub1 =
        stub_request(:post, "https://api.flowdock.com/messages").to_return(
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
          provider: "flowdock",
          data: {
            flow_token: "5d1fe04cf66e078d6a2b579ddb8a465b",
          },
        )
      expect(described_class.get_channel_by_name("5d1fe04cf66e078d6a2b579ddb8a465b")).to eq(
        expected,
      )
    end
  end
end

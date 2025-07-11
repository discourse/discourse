# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseChatIntegration::Provider::PowerAutomateProvider do
  let(:post) { Fabricate(:post) }

  describe ".trigger_notifications" do
    before { SiteSetting.chat_integration_powerautomate_enabled = true }

    let(:chan1) do
      DiscourseChatIntegration::Channel.create!(
        provider: "powerautomate",
        data: {
          name: "discourse",
          webhook_url:
            "https://prod-189.westus.logic.azure.com:443/workflows/c94b462906e64fe8a7299043706be96e/triggers/manual/paths/invoke?api-version=2016-06-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=-cmkg1oG-88dP3Yqdh62yTG1LUtJFcB91rQisorfw_w",
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
          provider: "powerautomate",
          data: {
            name: "discourse",
            webhook_url:
              "https://prod-189.westus.logic.azure.com:443/workflows/c94b462906e64fe8a7299043706be96e/triggers/manual/paths/invoke?api-version=2016-06-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=-cmkg1oG-88dP3Yqdh62yTG1LUtJFcB91rQisorfw_w",
          },
        )
      expect(described_class.get_channel_by_name("discourse")).to eq(expected)
    end
  end
end

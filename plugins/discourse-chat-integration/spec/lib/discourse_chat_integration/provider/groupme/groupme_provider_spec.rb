# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseChatIntegration::Provider::GroupmeProvider do
  let(:post) { Fabricate(:post) }

  describe ".trigger_notifications" do
    before do
      SiteSetting.chat_integration_groupme_enabled = true
      SiteSetting.chat_integration_groupme_bot_ids = "1a2b3c4d5e6f7g"
    end

    let(:chan1) do
      DiscourseChatIntegration::Channel.create!(
        provider: "groupme",
        data: {
          groupme_instance_name: "my instance",
        },
      )
    end

    it "sends a request" do
      stub1 = stub_request(:post, "https://api.groupme.com/v3/bots/post").to_return(status: 200)
      described_class.trigger_notification(post, chan1, nil)
      expect(stub1).to have_been_requested.once
    end

    it "handles errors correctly" do
      stub1 =
        stub_request(:post, "https://api.groupme.com/v3/bots/post").to_return(
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
          provider: "groupme",
          data: {
            groupme_instance_name: "my instance",
          },
        )
      expect(described_class.get_channel_by_name("my instance")).to eq(expected)
    end
  end
end

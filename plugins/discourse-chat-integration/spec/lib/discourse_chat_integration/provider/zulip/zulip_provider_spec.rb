# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseChatIntegration::Provider::ZulipProvider do
  let(:post) { Fabricate(:post) }

  describe ".trigger_notifications" do
    before do
      SiteSetting.chat_integration_zulip_enabled = true
      SiteSetting.chat_integration_zulip_server = "https://hello.world"
      SiteSetting.chat_integration_zulip_bot_email_address = "some_bot@example.com"
      SiteSetting.chat_integration_zulip_bot_api_key = "secret"
    end

    let(:chan1) do
      DiscourseChatIntegration::Channel.create!(
        provider: "zulip",
        data: {
          stream: "general",
          subject: "Discourse Notifications",
        },
      )
    end

    it "sends a webhook request" do
      stub1 = stub_request(:post, "https://hello.world/api/v1/messages").to_return(status: 200)
      described_class.trigger_notification(post, chan1, nil)
      expect(stub1).to have_been_requested.once
    end

    it "handles errors correctly" do
      stub1 =
        stub_request(:post, "https://hello.world/api/v1/messages").to_return(
          status: 400,
          body: "{}",
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
      created =
        DiscourseChatIntegration::Channel.create!(
          provider: "zulip",
          data: {
            stream: "foo",
            subject: "Discourse Notifications",
          },
        )
      channel = described_class.get_channel_by_name("foo")
      expect(channel).to eq(created)
    end
  end
end

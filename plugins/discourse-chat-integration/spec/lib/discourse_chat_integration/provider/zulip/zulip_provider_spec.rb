# frozen_string_literal: true

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
          channel: "general",
          topic: "Discourse Notifications",
        },
      )
    end

    let(:chan_no_topic) do
      DiscourseChatIntegration::Channel.create!(provider: "zulip", data: { channel: "general" })
    end

    it "sends a webhook request" do
      stub1 = stub_request(:post, "https://hello.world/api/v1/messages").to_return(status: 200)
      described_class.trigger_notification(post, chan1, nil)
      expect(stub1).to have_been_requested.once
    end

    it "uses the fixed topic when configured" do
      stub1 =
        stub_request(:post, "https://hello.world/api/v1/messages").with(
          body: hash_including("topic" => "Discourse Notifications"),
        ).to_return(status: 200)
      described_class.trigger_notification(post, chan1, nil)
      expect(stub1).to have_been_requested.once
    end

    it "uses the Discourse thread title as topic when no topic is configured" do
      stub1 =
        stub_request(:post, "https://hello.world/api/v1/messages").with(
          body: hash_including("topic" => post.topic.title),
        ).to_return(status: 200)
      described_class.trigger_notification(post, chan_no_topic, nil)
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
        DiscourseChatIntegration::ProviderError,
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
            channel: "foo",
            topic: "Discourse Notifications",
          },
        )
      channel = described_class.get_channel_by_name("foo")
      expect(channel).to eq(created)
    end
  end
end

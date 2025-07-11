# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseChatIntegration::Provider::MattermostProvider do
  let(:post) { Fabricate(:post) }

  describe ".trigger_notifications" do
    let(:upload) { Fabricate(:upload) }

    before do
      SiteSetting.chat_integration_mattermost_enabled = true
      SiteSetting.chat_integration_mattermost_webhook_url = "https://mattermost.blah/hook/abcd"
      SiteSetting.logo_small = upload
    end

    let(:chan1) do
      DiscourseChatIntegration::Channel.create!(
        provider: "mattermost",
        data: {
          identifier: "#awesomechannel",
        },
      )
    end

    it "sends a webhook request" do
      stub1 = stub_request(:post, "https://mattermost.blah/hook/abcd").to_return(status: 200)
      described_class.trigger_notification(post, chan1, nil)
      expect(stub1).to have_been_requested.once
    end

    describe "when mattermost icon is not configured" do
      it "defaults to the right icon" do
        message = described_class.mattermost_message(post, chan1)
        expect(message[:icon_url]).to eq(UrlHelper.absolute(upload.url))
      end
    end

    describe "when mattermost icon has been configured" do
      it "should use the right icon" do
        SiteSetting.chat_integration_mattermost_icon_url = "https://specific_logo"
        message = described_class.mattermost_message(post, chan1)
        expect(message[:icon_url]).to eq(SiteSetting.chat_integration_mattermost_icon_url)
      end
    end

    it "handles errors correctly" do
      stub1 =
        stub_request(:post, "https://mattermost.blah/hook/abcd").to_return(
          status: 500,
          body: "error",
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
          provider: "mattermost",
          data: {
            identifier: "#awesomechannel",
          },
        )
      expect(described_class.get_channel_by_name("#awesomechannel")).to eq(expected)
    end
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseChatIntegration::Provider::TeamsProvider do
  let(:post) { Fabricate(:post) }

  describe ".trigger_notifications" do
    before { SiteSetting.chat_integration_teams_enabled = true }

    let(:chan1) do
      DiscourseChatIntegration::Channel.create!(
        provider: "teams",
        data: {
          name: "discourse",
          webhook_url:
            "https://outlook.office.com/webhook/677980e4-e03b-4a5e-ad29-dc1ee0c32a80@9e9b5238-5ab2-496a-8e6a-e9cf05c7eb5c/IncomingWebhook/e7a1006ded44478992769d0c4f391e34/e028ca8a-e9c8-4c6c-a4d8-578f881a3cff",
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

    describe "with nil user.name" do
      before { post.user.update!(name: nil) }

      it "handles nil username correctly" do
        message = described_class.get_message(post)
        name = message[:sections].first[:facts].first[:name]
        expect(name).to eq("")
      end
    end
  end

  describe ".get_channel_by_name" do
    it "returns the right channel" do
      expected =
        DiscourseChatIntegration::Channel.create!(
          provider: "teams",
          data: {
            name: "discourse",
            webhook_url:
              "https://outlook.office.com/webhook/677980e4-e03b-4a5e-ad29-dc1ee0c32a80@9e9b5238-5ab2-496a-8e6a-e9cf05c7eb5c/IncomingWebhook/e7a1006ded44478992769d0c4f391e34/e028ca8a-e9c8-4c6c-a4d8-578f881a3cff",
          },
        )
      expect(described_class.get_channel_by_name("discourse")).to eq(expected)
    end
  end
end

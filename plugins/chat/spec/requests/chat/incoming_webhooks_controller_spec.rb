# frozen_string_literal: true

RSpec.describe Chat::IncomingWebhooksController do
  fab!(:chat_channel) { Fabricate(:category_channel) }
  fab!(:webhook) { Fabricate(:incoming_chat_webhook, chat_channel: chat_channel) }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_debug_webhook_payloads = true
  end

  let(:valid_payload) { { text: "A new signup woo!" } }

  describe "#create_message" do
    context "with chat disabled" do
      before { SiteSetting.chat_enabled = false }

      it "returns a 404" do
        post "/chat/hooks/#{webhook.key}.json", params: valid_payload
        expect(response.status).to eq(404)
      end
    end

    it "errors with invalid key" do
      post "/chat/hooks/null.json"
      expect(response.status).to eq(400)
    end

    it "errors when no body is present" do
      post "/chat/hooks/#{webhook.key}.json"
      expect(response.status).to eq(400)
    end

    it "errors when the body is over chat_maximum_message_length characters" do
      post "/chat/hooks/#{webhook.key}.json",
           params: {
             text: "$" * (SiteSetting.chat_maximum_message_length + 1),
           }
      expect(response.status).to eq(422)
    end

    it "creates a new chat message" do
      expect { post "/chat/hooks/#{webhook.key}.json", params: valid_payload }.to change {
        Chat::Message.where(chat_channel: chat_channel).count
      }.by(1)
      expect(response.status).to eq(200)
      chat_webhook_event = Chat::WebhookEvent.last
      expect(chat_webhook_event.chat_message_id).to eq(Chat::Message.last.id)
    end

    it "handles create message failures gracefully and does not create the chat message" do
      watched_word = Fabricate(:watched_word, action: WatchedWord.actions[:block])

      expect {
        post "/chat/hooks/#{webhook.key}.json", params: { text: "hey #{watched_word.word}" }
      }.not_to change { Chat::Message.where(chat_channel: chat_channel).count }
      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to include(
        "Sorry, you can't post the word '#{watched_word.word}'; it's not allowed.",
      )
    end

    it "handles create message failures gracefully if the channel is read only" do
      chat_channel.update!(status: :read_only)
      expect {
        post "/chat/hooks/#{webhook.key}.json", params: { text: "hey this is a message" }
      }.not_to change { Chat::Message.where(chat_channel: chat_channel).count }
      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to include(
        I18n.t("chat.errors.channel_new_message_disallowed.read_only"),
      )
    end

    describe "rate limiting" do
      it "rate limits" do
        RateLimiter.enable
        10.times { post "/chat/hooks/#{webhook.key}.json", params: valid_payload }
        expect(response.status).to eq(200)

        post "/chat/hooks/#{webhook.key}.json", params: valid_payload
        expect(response.status).to eq(429)
      end
    end
  end

  describe "#create_message_slack_compatible" do
    context "with chat disabled" do
      before { SiteSetting.chat_enabled = false }

      it "returns a 404" do
        post "/chat/hooks/#{webhook.key}/slack.json", params: valid_payload
        expect(response.status).to eq(404)
      end
    end

    it "processes the text param with SlackCompatibility" do
      expect {
        post "/chat/hooks/#{webhook.key}/slack.json", params: { text: "A new signup woo <!here>!" }
      }.to change { Chat::Message.where(chat_channel: chat_channel).count }.by(1)
      expect(response.status).to eq(200)
      expect(Chat::Message.last.message).to eq("A new signup woo @here!")
    end

    it "processes the attachments param with SlackCompatibility, using the fallback" do
      payload_data = {
        attachments: [
          {
            color: "#F4511E",
            title: "New+alert:+#46353",
            text:
              "\"[StatusCake]+https://www.test_notification.com+(StatusCake+Test+Alert):+Down,\"",
            fallback:
              "New+alert:+\"[StatusCake]+https://www.test_notification.com+(StatusCake+Test+Alert):+Down,\"+<https://eu.opsg.in/a/i/test/blahguid|46353>\nTags:+",
            title_link: "https://eu.opsg.in/a/i/test/blahguid",
          },
        ],
      }
      expect { post "/chat/hooks/#{webhook.key}/slack.json", params: payload_data }.to change {
        Chat::Message.where(chat_channel: chat_channel).count
      }.by(1)
      expect(Chat::Message.last.message).to eq(
        "New alert: \"[StatusCake] https://www.test_notification.com (StatusCake Test Alert): Down,\" [46353](https://eu.opsg.in/a/i/test/blahguid)\nTags:",
      )
      expect {
        post "/chat/hooks/#{webhook.key}/slack.json", params: { payload: payload_data }
      }.to change { Chat::Message.where(chat_channel: chat_channel).count }.by(1)
    end

    it "can process the payload when it's a JSON string" do
      payload_data = {
        attachments: [
          {
            color: "#F4511E",
            title: "New+alert:+#46353",
            text:
              "\"[StatusCake]+https://www.test_notification.com+(StatusCake+Test+Alert):+Down,\"",
            fallback:
              "New+alert:+\"[StatusCake]+https://www.test_notification.com+(StatusCake+Test+Alert):+Down,\"+<https://eu.opsg.in/a/i/test/blahguid|46353>\nTags:+",
            title_link: "https://eu.opsg.in/a/i/test/blahguid",
          },
        ],
      }
      expect {
        post "/chat/hooks/#{webhook.key}/slack.json", params: { payload: payload_data.to_json }
      }.to change { Chat::Message.where(chat_channel: chat_channel).count }.by(1)
      expect(Chat::Message.last.message).to eq(
        "New alert: \"[StatusCake] https://www.test_notification.com (StatusCake Test Alert): Down,\" [46353](https://eu.opsg.in/a/i/test/blahguid)\nTags:",
      )
    end
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe "DiscourseAi::Discord::BotController", type: :request do
  let(:public_key) { "your_public_key_here" }
  let(:signature) { "valid_signature" }
  let(:timestamp) { Time.now.to_i.to_s }
  let(:body) { { type: 1 }.to_json }
  let(:headers) { { "X-Signature-Ed25519" => signature, "X-Signature-Timestamp" => timestamp } }

  before do
    enable_current_plugin
    SiteSetting.ai_discord_app_public_key = public_key
    allow_any_instance_of(DiscourseAi::Discord::BotController).to receive(
      :verify_request!,
    ).and_return(true)
  end

  describe "POST /discourse-ai/discord/interactions" do
    context "when interaction type is 1 (PING)" do
      it "responds with type 1" do
        post "/discourse-ai/discord/interactions", params: body, headers: headers
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq("type" => 1)
      end
    end

    context "when interaction type is not 1" do
      let(:guild_id) { "1234567890" }
      let(:interaction_body) do
        {
          type: 2,
          guild_id: guild_id,
          data: {
            options: [{ value: "test query" }],
          },
          token: "interaction_token",
        }.to_json
      end

      before do
        allow(SiteSetting).to receive(:ai_discord_allowed_guilds_map).and_return([guild_id])
      end

      xit "enqueues a job to handle the interaction" do
        expect {
          post "/discourse-ai/discord/interactions", params: interaction_body, headers: headers
        }.to have_enqueued_job(Jobs::StreamDiscordReply)
      end

      it "responds with a deferred message" do
        post "/discourse-ai/discord/interactions", params: interaction_body, headers: headers
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq(
          "type" => 5,
          "data" => {
            "content" => "Searching...",
          },
        )
      end
    end
  end
end

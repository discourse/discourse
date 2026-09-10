# frozen_string_literal: true

require "rails_helper"

RSpec.describe Voice::AgentTokensController do
  fab!(:user)
  fab!(:room, :voice_room)
  fab!(:integration) { Fabricate(:voice_agent_integration, rooms: [room]) }
  let(:credential) { Voice::AgentManager.create_credential!(integration) }

  before do
    SiteSetting.voice_enabled = true
    SiteSetting.voice_livekit_url = "wss://livekit.example.com"
    SiteSetting.voice_livekit_api_key = "key"
    SiteSetting.voice_livekit_api_secret = "secret"
    Voice::ParticipantTracker.pin_transport!(room.id, "livekit")
    Voice::ParticipantTracker.add(room.id, user.id)
  end

  def request_token(room_id: room.id, secret: credential)
    post "/voice/agent-token.json",
         params: {
           room_id:,
         },
         headers: {
           "Authorization" => "Bearer #{secret}",
         }
  end

  describe "#create" do
    it "issues a short-lived listener token without establishing presence or attendance" do
      request_token

      expect(response.status).to eq(200)
      payload = JWT.decode(response.parsed_body["token"], "secret", true, algorithm: "HS256").first
      expect(payload["sub"]).to eq(integration.bot_user_id.to_s)
      expect(payload["metadata"]).to eq(response.parsed_body["participant_session_id"])
      expect(payload["video"]).to include(
        "room" => Voice::Livekit.room_name(room),
        "canPublish" => false,
        "canSubscribe" => true,
        "canUpdateOwnMetadata" => false,
      )
      expect(payload["exp"]).to be_within(2).of(2.minutes.from_now.to_i)
      expect(response.headers["Cache-Control"]).to include("no-store")
      expect(Voice::ParticipantTracker.user_ids(room.id)).to eq([user.id])
      expect(Voice::Session.where(user_id: integration.bot_user_id)).to be_empty
    end

    it "allows an administrator-authorized speaker to publish" do
      integration.update!(role: Voice::AgentIntegration::ROLE_SPEAKER)
      request_token
      expect(response.status).to eq(200)
      payload = JWT.decode(response.parsed_body["token"], "secret", true, algorithm: "HS256").first
      expect(payload["video"]["canPublish"]).to eq(true)
    end

    it "rejects invalid credentials and rooms outside the integration scope" do
      request_token(secret: "invalid")
      expect(response.status).to eq(403)
      request_token(room_id: Fabricate(:voice_room).id)
      expect(response.status).to eq(403)
    end

    it "rejects revoked integrations and excluded rooms" do
      credential
      integration.revoke!
      request_token
      expect(response.status).to eq(403)
      integration.restore!
      Voice::AgentManager.exclude!(room:, user_id: integration.bot_user_id, duration: 60)
      request_token
      expect(response.status).to eq(403)
    end

    it "rejects empty rooms and mesh rooms" do
      Voice::ParticipantTracker.remove(room.id, user.id)
      request_token
      expect(response.status).to eq(403)
      Voice::ParticipantTracker.add(room.id, user.id)
      Voice::ParticipantTracker.clear_transport_pin(room.id)
      Voice::ParticipantTracker.pin_transport!(room.id, "mesh")
      request_token
      expect(response.status).to eq(403)
    end

    it "rejects a bot suspended after integration setup" do
      integration.bot_user.update!(suspended_till: 1.day.from_now)
      request_token
      expect(response.status).to eq(403)
    end
  end
end

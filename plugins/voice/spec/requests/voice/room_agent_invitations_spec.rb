# frozen_string_literal: true

require "rails_helper"

RSpec.describe Voice::RoomsController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:room) { Fabricate(:voice_room, public: true) }

  before do
    SiteSetting.voice_enabled = true
    SiteSetting.voice_livekit_url = "wss://test.livekit.cloud"
    SiteSetting.voice_livekit_api_key = "key"
    SiteSetting.voice_livekit_api_secret = "secret"
    SiteSetting.voice_livekit_agent_enabled = true
    Voice::ParticipantTracker.pin_transport!(room.id, "livekit")
    Voice::ParticipantTracker.add(room.id, user.id)
    @dispatch =
      stub_request(
        :post,
        "https://test.livekit.cloud/twirp/livekit.AgentDispatchService/CreateDispatch",
      ).to_return(status: 200, body: { id: "AD_test" }.to_json)
    stub_request(
      :post,
      "https://test.livekit.cloud/twirp/livekit.AgentDispatchService/DeleteDispatch",
    ).to_return(status: 200, body: "{}")
  end

  describe "#invite_agent" do
    it "dispatches the chosen agent for an admin" do
      sign_in(admin)

      post "/voice/rooms/#{room.id}/invite_agent.json", params: { agent_name: "assistant" }

      expect(response.status).to eq(201)
      expect(response.parsed_body).to eq("dispatch_id" => "AD_test")
      expect(
        @dispatch.with(body: hash_including("agent_name" => "assistant")),
      ).to have_been_requested.once
    end

    it "rejects missing, blank, oversized, and non-string names" do
      sign_in(admin)
      [nil, " ", "a" * 257, ["assistant"]].each do |name|
        post "/voice/rooms/#{room.id}/invite_agent.json", params: { agent_name: name }
        expect(response.status).to eq(400)
      end
      expect(@dispatch).not_to have_been_requested
    end

    it "rejects non-admin invitations" do
      [user, moderator].each do |actor|
        sign_in(actor)
        post "/voice/rooms/#{room.id}/invite_agent.json", params: { agent_name: "assistant" }
        expect(response.status).to eq(403)
      end
      expect(@dispatch).not_to have_been_requested
    end

    it "rejects invitations when disabled or the bot no longer exists" do
      sign_in(admin)
      SiteSetting.voice_livekit_agent_enabled = false
      post "/voice/rooms/#{room.id}/invite_agent.json", params: { agent_name: "assistant" }
      expect(response.status).to eq(403)

      SiteSetting.voice_livekit_agent_enabled = true
      Voice::AgentBot.user.delete
      post "/voice/rooms/#{room.id}/invite_agent.json", params: { agent_name: "assistant" }
      expect(response.status).to eq(403)
      expect(@dispatch).not_to have_been_requested
    end

    it "rejects a private room even for admins" do
      sign_in(admin)
      room.update!(public: false)

      post "/voice/rooms/#{room.id}/invite_agent.json", params: { agent_name: "assistant" }

      expect(response.status).to eq(403)
      expect(@dispatch).not_to have_been_requested
    end

    it "reports a provider failure" do
      sign_in(admin)
      stub_request(
        :post,
        "https://test.livekit.cloud/twirp/livekit.AgentDispatchService/CreateDispatch",
      ).to_return(status: 503)

      post "/voice/rooms/#{room.id}/invite_agent.json", params: { agent_name: "assistant" }

      expect(response.status).to eq(503)
    end
  end

  describe "#kick" do
    it "allows the admin to immediately invite the bot again" do
      sign_in(admin)
      post "/voice/rooms/#{room.id}/invite_agent.json", params: { agent_name: "assistant" }
      bot = Voice::AgentBot.user
      stub_request(
        :post,
        "https://test.livekit.cloud/twirp/livekit.RoomService/RemoveParticipant",
      ).to_return(status: 200, body: "{}")

      delete "/voice/rooms/#{room.id}/kick.json", params: { user_id: bot.id }

      expect(response.status).to eq(204)
      post "/voice/rooms/#{room.id}/invite_agent.json", params: { agent_name: "assistant" }
      expect(response.status).to eq(201)
      expect(@dispatch).to have_been_requested.twice
    end
  end
end

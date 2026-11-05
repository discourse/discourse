# frozen_string_literal: true

require "rails_helper"

RSpec.describe Live::RoomsController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:room) { Fabricate(:live_room, public: true) }

  before do
    SiteSetting.live_enabled = true
    SiteSetting.live_livekit_url = "wss://test.livekit.cloud"
    SiteSetting.live_livekit_api_key = "key"
    SiteSetting.live_livekit_api_secret = "secret"
    SiteSetting.live_livekit_agent_enabled = true
    Live::ParticipantTracker.pin_transport!(room.id, "livekit")
    Live::ParticipantTracker.add(room.id, user.id)
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

      post "/live/rooms/#{room.id}/invite_agent.json", params: { agent_name: "assistant" }

      expect(response.status).to eq(201)
      expect(response.parsed_body).to eq("dispatch_id" => "AD_test")
      expect(
        @dispatch.with(body: hash_including("agent_name" => "assistant")),
      ).to have_been_requested.once
    end

    it "rejects missing, blank, oversized, and non-string names" do
      sign_in(admin)
      [nil, " ", "a" * 257, ["assistant"]].each do |name|
        post "/live/rooms/#{room.id}/invite_agent.json", params: { agent_name: name }
        expect(response.status).to eq(400)
      end
      expect(@dispatch).not_to have_been_requested
    end

    it "rejects users outside the invite groups" do
      [user, moderator].each do |actor|
        sign_in(actor)
        post "/live/rooms/#{room.id}/invite_agent.json", params: { agent_name: "assistant" }
        expect(response.status).to eq(403)
      end
      expect(@dispatch).not_to have_been_requested
    end

    it "dispatches for a non-admin in the invite groups" do
      SiteSetting.live_livekit_agent_invite_allowed_groups =
        "#{Group::AUTO_GROUPS[:admins]}|#{Group::AUTO_GROUPS[:moderators]}"
      sign_in(moderator)

      post "/live/rooms/#{room.id}/invite_agent.json", params: { agent_name: "assistant" }

      expect(response.status).to eq(201)
      expect(@dispatch).to have_been_requested.once
    end

    it "rejects invitations when disabled or the bot no longer exists" do
      sign_in(admin)
      SiteSetting.live_livekit_agent_enabled = false
      post "/live/rooms/#{room.id}/invite_agent.json", params: { agent_name: "assistant" }
      expect(response.status).to eq(403)

      SiteSetting.live_livekit_agent_enabled = true
      Live::AgentBot.user.delete
      post "/live/rooms/#{room.id}/invite_agent.json", params: { agent_name: "assistant" }
      expect(response.status).to eq(403)
      expect(@dispatch).not_to have_been_requested
    end

    it "rejects a private room even for admins" do
      sign_in(admin)
      room.update!(public: false)

      post "/live/rooms/#{room.id}/invite_agent.json", params: { agent_name: "assistant" }

      expect(response.status).to eq(403)
      expect(@dispatch).not_to have_been_requested
    end

    it "reports a provider failure" do
      sign_in(admin)
      stub_request(
        :post,
        "https://test.livekit.cloud/twirp/livekit.AgentDispatchService/CreateDispatch",
      ).to_return(status: 503)

      post "/live/rooms/#{room.id}/invite_agent.json", params: { agent_name: "assistant" }

      expect(response.status).to eq(503)
    end
  end

  describe "#kick" do
    it "allows the admin to immediately invite the bot again" do
      sign_in(admin)
      post "/live/rooms/#{room.id}/invite_agent.json", params: { agent_name: "assistant" }
      bot = Live::AgentBot.user
      stub_request(
        :post,
        "https://test.livekit.cloud/twirp/livekit.RoomService/RemoveParticipant",
      ).to_return(status: 200, body: "{}")

      delete "/live/rooms/#{room.id}/kick.json", params: { user_id: bot.id }

      expect(response.status).to eq(204)
      post "/live/rooms/#{room.id}/invite_agent.json", params: { agent_name: "assistant" }
      expect(response.status).to eq(201)
      expect(@dispatch).to have_been_requested.twice
    end
  end
end

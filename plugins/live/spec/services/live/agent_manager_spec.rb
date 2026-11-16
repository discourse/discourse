# frozen_string_literal: true

require "rails_helper"

RSpec.describe Live::AgentManager do
  fab!(:user)
  fab!(:room) { Fabricate(:live_room, public: true) }
  fab!(:other_room) { Fabricate(:live_room, public: true) }

  before do
    SiteSetting.live_enabled = true
    SiteSetting.live_livekit_url = "wss://test.livekit.cloud"
    SiteSetting.live_livekit_api_key = "key"
    SiteSetting.live_livekit_api_secret = "secret"
    SiteSetting.live_livekit_agent_enabled = true
    [room, other_room].each do |live_room|
      Live::ParticipantTracker.pin_transport!(live_room.id, "livekit")
      Live::ParticipantTracker.add(live_room.id, user.id)
    end
    stub_request(
      :post,
      "https://test.livekit.cloud/twirp/livekit.RoomService/DeleteRoom",
    ).to_return(status: 503)
  end

  describe ".evict_agents_in_room!" do
    it "revokes an admission proof before a dispatch is saved without revoking other rooms" do
      bot_id = Live::AgentBot.user.id
      session_id = described_class.authorize_session!(room:, agent_name: "assistant")
      other_session_id =
        described_class.authorize_session!(room: other_room, agent_name: "assistant")

      described_class.evict_agents_in_room!(room)
      Live::ParticipantTracker.pin_transport!(room.id, "livekit")

      expect(
        described_class.authorized_session(room:, user_id: bot_id, metadata: session_id),
      ).to be_nil
      expect(
        described_class.authorized_session(
          room: other_room,
          user_id: bot_id,
          metadata: other_session_id,
        ),
      ).to be_present
    end
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe Voice::AgentManager do
  fab!(:user)
  fab!(:room) { Fabricate(:voice_room, public: true) }
  fab!(:other_room) { Fabricate(:voice_room, public: true) }

  before do
    SiteSetting.voice_enabled = true
    SiteSetting.voice_livekit_url = "wss://test.livekit.cloud"
    SiteSetting.voice_livekit_api_key = "key"
    SiteSetting.voice_livekit_api_secret = "secret"
    SiteSetting.voice_livekit_agent_enabled = true
    [room, other_room].each do |voice_room|
      Voice::ParticipantTracker.pin_transport!(voice_room.id, "livekit")
      Voice::ParticipantTracker.add(voice_room.id, user.id)
    end
    stub_request(
      :post,
      "https://test.livekit.cloud/twirp/livekit.RoomService/DeleteRoom",
    ).to_return(status: 503)
  end

  describe ".evict_agents_in_room!" do
    it "revokes an admission proof before a dispatch is saved without revoking other rooms" do
      bot_id = Voice::AgentBot.user.id
      session_id = described_class.authorize_session!(room:, agent_name: "assistant")
      other_session_id =
        described_class.authorize_session!(room: other_room, agent_name: "assistant")

      described_class.evict_agents_in_room!(room)
      Voice::ParticipantTracker.pin_transport!(room.id, "livekit")

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

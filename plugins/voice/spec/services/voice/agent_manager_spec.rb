# frozen_string_literal: true

require "rails_helper"

RSpec.describe Voice::AgentManager do
  fab!(:user)
  fab!(:other_user, :user)
  fab!(:room, :voice_room)
  fab!(:integration) { Fabricate(:voice_agent_integration, rooms: [room]) }
  let(:session_id) { described_class.authorize_session!(integration:, room:) }
  let(:participant) do
    { identity: integration.bot_user_id.to_s, metadata: session_id, sid: "PA_current" }
  end

  before do
    SiteSetting.voice_enabled = true
    SiteSetting.voice_livekit_url = "wss://livekit.example.com"
    SiteSetting.voice_livekit_api_key = "key"
    SiteSetting.voice_livekit_api_secret = "secret"
    Voice::ParticipantTracker.pin_transport!(room.id, "livekit")
    Voice::ParticipantTracker.add(room.id, user.id)
    stub_request(
      :post,
      "https://livekit.example.com/twirp/livekit.RoomService/RemoveParticipant",
    ).to_return(status: 200, body: "{}")
    stub_request(
      :post,
      "https://livekit.example.com/twirp/livekit.RoomService/DeleteRoom",
    ).to_return(status: 200, body: "{}")
  end

  def provider_participants(participants)
    stub_request(
      :post,
      "https://livekit.example.com/twirp/livekit.RoomService/ListParticipants",
    ).to_return(status: 200, body: { participants: }.to_json)
  end

  describe ".reconcile" do
    it "establishes authorized presence through the next sweep without consuming human capacity" do
      provider_participants([participant])
      described_class.reconcile(room)
      freeze_time(61.seconds.from_now)
      expect(Voice::ParticipantTracker.agent_user_ids(room.id)).to eq([integration.bot_user_id])
      Voice::ParticipantTracker.add(room.id, user.id)
      expect(Voice::ParticipantTracker.add_within_capacity(room.id, other_user.id, 2)).to eq(:added)
      expect(Voice::ParticipantTracker.get_metadata(room.id, integration.bot_user_id)).to include(
        external_agent: true,
        role: "participant",
      )
      expect(Voice::Session.where(user_id: integration.bot_user_id)).to be_empty
    end

    it "rejects a superseded token and expires previously visible media" do
      provider_participants([participant])
      described_class.reconcile(room)
      described_class.authorize_session!(integration:, room:)
      described_class.reconcile(room)
      expect(Voice::ParticipantTracker.agent_user_ids(room.id)).to be_empty
      expect(
        a_request(:post, "https://livekit.example.com/twirp/livekit.RoomService/RemoveParticipant"),
      ).to have_been_made
    end

    it "removes a departed agent even if its departure webhook was missed" do
      provider_participants([participant])
      described_class.reconcile(room)
      provider_participants([])
      described_class.reconcile(room)
      expect(Voice::ParticipantTracker.agent_user_ids(room.id)).to be_empty
    end

    it "expires agent presence after repeated provider failures" do
      provider_participants([participant])
      described_class.reconcile(room)
      stub_request(
        :post,
        "https://livekit.example.com/twirp/livekit.RoomService/ListParticipants",
      ).to_return(status: 503)
      described_class.reconcile(room)
      expect(Voice::ParticipantTracker.agent_user_ids(room.id)).to eq([integration.bot_user_id])
      freeze_time(181.seconds.from_now)
      expect(Voice::ParticipantTracker.agent_user_ids(room.id)).to be_empty
    end
  end

  describe ".evict_integration!" do
    it "revokes pending sessions so restoring the integration cannot revive an old token" do
      session_id
      integration.revoke!
      described_class.evict_integration!(integration)
      integration.restore!
      expect(
        described_class.authorized_session?(
          room:,
          user_id: integration.bot_user_id,
          metadata: session_id,
        ),
      ).to eq(false)
    end
  end

  describe ".exclude!" do
    it "allows a fresh session after a timeout while keeping the old token revoked" do
      session_id
      described_class.exclude!(room:, user_id: integration.bot_user_id, duration: 60)
      expect(integration.excluded_from?(room)).to eq(true)
      freeze_time(61.seconds.from_now)
      Voice::ParticipantTracker.add(room.id, user.id)
      Voice::ParticipantTracker.pin_transport!(room.id, "livekit")
      expect(integration.excluded_from?(room)).to eq(false)
      expect(
        described_class.authorized_session?(
          room:,
          user_id: integration.bot_user_id,
          metadata: session_id,
        ),
      ).to eq(false)
      expect(described_class.authorize!(integration:, room:)).to eq(integration)
    end

    it "keeps indefinite exclusions until an administrator removes them" do
      described_class.exclude!(room:, user_id: integration.bot_user_id, duration: 0)
      freeze_time(1.year.from_now)
      expect(integration.excluded_from?(room)).to eq(true)
    end
  end

  describe ".evict_agents_in_room!" do
    it "ends agent participation and revokes pending tokens while preserving integration configuration" do
      provider_participants([participant])
      described_class.reconcile(room)
      Voice::ParticipantTracker.remove(room.id, user.id)
      described_class.evict_agents_in_room!(room)
      Voice::ParticipantTracker.add(room.id, user.id)
      Voice::ParticipantTracker.pin_transport!(room.id, "livekit")
      expect(Voice::ParticipantTracker.agent_user_ids(room.id)).to be_empty
      expect(integration.reload).to be_active
      expect(
        described_class.authorized_session?(
          room:,
          user_id: integration.bot_user_id,
          metadata: session_id,
        ),
      ).to eq(false)
    end
  end
end

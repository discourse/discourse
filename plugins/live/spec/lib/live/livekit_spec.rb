# frozen_string_literal: true

require "rails_helper"

RSpec.describe Live::Livekit do
  fab!(:user)
  fab!(:room) { Fabricate(:live_room, public: true) }

  before do
    SiteSetting.live_enabled = true
    SiteSetting.live_livekit_url = "wss://livekit.example.com"
    SiteSetting.live_livekit_api_key = "lk_api_key"
    SiteSetting.live_livekit_api_secret = "lk_api_secret"
  end

  def decoded_token
    token = described_class.mint_token(user: user, room: room, guardian: user.guardian)
    JWT.decode(token, SiteSetting.live_livekit_api_secret, true, algorithm: "HS256").first
  end

  describe ".configured?" do
    it "is true only when url, key, and secret are all present" do
      expect(described_class.configured?).to eq(true)

      SiteSetting.live_livekit_api_secret = ""
      expect(described_class.configured?).to eq(false)

      SiteSetting.live_livekit_api_secret = "lk_api_secret"
      SiteSetting.live_livekit_url = ""
      expect(described_class.configured?).to eq(false)
    end
  end

  describe ".available_for?" do
    it "follows the room policy" do
      SiteSetting.live_livekit_room_policy = "disabled"
      expect(described_class.available_for?(room)).to eq(false)

      SiteSetting.live_livekit_room_policy = "all_rooms"
      expect(described_class.available_for?(room)).to eq(true)
    end

    it "follows the room's own flag under the per_room policy" do
      SiteSetting.live_livekit_room_policy = "per_room"

      expect(described_class.available_for?(room)).to eq(false)

      room.update!(livekit_enabled: true)
      expect(described_class.available_for?(room)).to eq(true)
    end

    it "is false when the policy allows but the config is incomplete" do
      SiteSetting.live_livekit_room_policy = "all_rooms"
      SiteSetting.live_livekit_api_secret = ""

      expect(described_class.available_for?(room)).to eq(false)
    end
  end

  describe ".room_name" do
    it "namespaces by database name and room id" do
      db = RailsMultisite::ConnectionManagement.current_db
      expect(described_class.room_name(room)).to eq("#{db}-r#{room.id}")
    end

    it "prefers the configured prefix over the database name" do
      SiteSetting.live_livekit_room_prefix = "acme"
      expect(described_class.room_name(room)).to eq("acme-r#{room.id}")
    end
  end

  describe ".mint_token" do
    it "raises MintError when not fully configured" do
      SiteSetting.live_livekit_api_secret = ""

      expect { decoded_token }.to raise_error(described_class::MintError)
    end

    it "mints a least-privilege token for a speaker in a video room" do
      room.update!(video_enabled: true)

      freeze_time

      payload = decoded_token

      expect(payload["iss"]).to eq("lk_api_key")
      expect(payload["sub"]).to eq(user.id.to_s)
      expect(payload["name"]).to eq(user.username)
      expect(payload["exp"]).to eq(described_class::TOKEN_TTL.from_now.to_i)
      expect(payload["video"]).to eq(
        "room" => described_class.room_name(room),
        "roomJoin" => true,
        "canSubscribe" => true,
        "canPublish" => true,
        "canPublishSources" => %w[microphone camera screen_share screen_share_audio],
        "canPublishData" => false,
        "canUpdateOwnMetadata" => false,
        "roomCreate" => false,
        "roomList" => false,
        "roomAdmin" => false,
        "roomRecord" => false,
        "recorder" => false,
        "hidden" => false,
      )
    end

    it "grants only the camera source when screen sharing is not allowed" do
      SiteSetting.live_screen_share_allowed_groups = ""
      room.update!(video_enabled: true)

      payload = decoded_token

      expect(payload["video"]["canPublishSources"]).to eq(%w[microphone camera])
    end

    it "grants only the screen sources when the camera is not allowed" do
      SiteSetting.live_video_allowed_groups = ""
      room.update!(video_enabled: true)

      payload = decoded_token

      expect(payload["video"]["canPublishSources"]).to eq(
        %w[microphone screen_share screen_share_audio],
      )
    end

    it "grants only the microphone source when the room has no video" do
      room.update!(video_enabled: false)

      payload = decoded_token

      expect(payload["video"]["canPublish"]).to eq(true)
      expect(payload["video"]["canPublishSources"]).to eq(["microphone"])
    end

    it "denies publishing entirely to a stage listener" do
      room.update!(room_type: Live::Room::ROOM_TYPE_STAGE)

      payload = decoded_token

      expect(payload["video"]["canSubscribe"]).to eq(true)
      expect(payload["video"]["canPublish"]).to eq(false)
      expect(payload["video"]["canPublishSources"]).to eq([])
    end

    it "grants all publish sources to a stage speaker when the room has video" do
      room.update!(room_type: Live::Room::ROOM_TYPE_STAGE, video_enabled: true)
      room.room_memberships.create!(user: user, role: Live::RoomMembership::ROLE_SPEAKER)

      payload = decoded_token

      expect(payload["video"]["canPublish"]).to eq(true)
      expect(payload["video"]["canPublishSources"]).to eq(
        %w[microphone camera screen_share screen_share_audio],
      )
    end

    it "grants only the microphone to a stage speaker when the room has no video" do
      room.update!(room_type: Live::Room::ROOM_TYPE_STAGE, video_enabled: false)
      room.room_memberships.create!(user: user, role: Live::RoomMembership::ROLE_SPEAKER)

      payload = decoded_token

      expect(payload["video"]["canPublish"]).to eq(true)
      expect(payload["video"]["canPublishSources"]).to eq(["microphone"])
    end
  end
end

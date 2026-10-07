# frozen_string_literal: true

require "rails_helper"
require_relative "../../../db/migrate/20241107000000_create_voice_rooms"
require_relative "../../../db/migrate/20260305162426_add_room_type_to_voice_rooms"
require_relative "../../../db/migrate/20260612135211_add_video_enabled_to_voice_rooms"
require_relative "../../../db/migrate/20260709165411_add_livekit_enabled_to_voice_rooms"

RSpec.describe Voice::Livekit do
  before do
    ActiveRecord::Migration.suppress_messages do
      CreateVoiceRooms.new.change unless ActiveRecord::Base.connection.table_exists?(:voice_rooms)
      unless ActiveRecord::Base.connection.column_exists?(:voice_rooms, :room_type)
        AddRoomTypeToVoiceRooms.new.change
      end
      unless ActiveRecord::Base.connection.column_exists?(:voice_rooms, :video_enabled)
        AddVideoEnabledToVoiceRooms.new.change
      end
      unless ActiveRecord::Base.connection.column_exists?(:voice_rooms, :livekit_enabled)
        AddLivekitEnabledToVoiceRooms.new.change
      end
    end
    Voice::Room.reset_column_information
  end

  fab!(:user)
  fab!(:room) { Fabricate(:voice_room, public: true) }

  before do
    SiteSetting.voice_enabled = true
    SiteSetting.voice_livekit_url = "wss://livekit.example.com"
    SiteSetting.voice_livekit_api_key = "lk_api_key"
    SiteSetting.voice_livekit_api_secret = "lk_api_secret"
  end

  def decoded_token
    token = described_class.mint_token(user: user, room: room, guardian: user.guardian)
    JWT.decode(token, SiteSetting.voice_livekit_api_secret, true, algorithm: "HS256").first
  end

  describe ".configured?" do
    it "is true only when url, key, and secret are all present" do
      expect(described_class.configured?).to eq(true)

      SiteSetting.voice_livekit_api_secret = ""
      expect(described_class.configured?).to eq(false)

      SiteSetting.voice_livekit_api_secret = "lk_api_secret"
      SiteSetting.voice_livekit_url = ""
      expect(described_class.configured?).to eq(false)
    end
  end

  describe ".available_for?" do
    it "follows the room policy" do
      SiteSetting.voice_livekit_room_policy = "disabled"
      expect(described_class.available_for?(room)).to eq(false)

      SiteSetting.voice_livekit_room_policy = "all_rooms"
      expect(described_class.available_for?(room)).to eq(true)
    end

    it "follows the room's own flag under the per_room policy" do
      SiteSetting.voice_livekit_room_policy = "per_room"

      expect(described_class.available_for?(room)).to eq(false)

      room.update!(livekit_enabled: true)
      expect(described_class.available_for?(room)).to eq(true)
    end

    it "is false when the policy allows but the config is incomplete" do
      SiteSetting.voice_livekit_room_policy = "all_rooms"
      SiteSetting.voice_livekit_api_secret = ""

      expect(described_class.available_for?(room)).to eq(false)
    end
  end

  describe ".room_name" do
    it "namespaces by database name and room id" do
      db = RailsMultisite::ConnectionManagement.current_db
      expect(described_class.room_name(room)).to eq("#{db}-r#{room.id}")
    end

    it "prefers the configured prefix over the database name" do
      SiteSetting.voice_livekit_room_prefix = "acme"
      expect(described_class.room_name(room)).to eq("acme-r#{room.id}")
    end
  end

  describe ".mint_token" do
    it "raises MintError when not fully configured" do
      SiteSetting.voice_livekit_api_secret = ""

      expect { decoded_token }.to raise_error(described_class::MintError)
    end

    it "mints a least-privilege token for a speaker in a video room" do
      SiteSetting.voice_video_enabled = true
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

    it "grants only the microphone source when the room has no video" do
      SiteSetting.voice_video_enabled = true
      room.update!(video_enabled: false)

      payload = decoded_token

      expect(payload["video"]["canPublish"]).to eq(true)
      expect(payload["video"]["canPublishSources"]).to eq(["microphone"])
    end

    it "denies publishing entirely to a stage listener" do
      room.update!(room_type: Voice::Room::ROOM_TYPE_STAGE)

      payload = decoded_token

      expect(payload["video"]["canSubscribe"]).to eq(true)
      expect(payload["video"]["canPublish"]).to eq(false)
      expect(payload["video"]["canPublishSources"]).to eq([])
    end

    it "grants all publish sources to a stage speaker when the room has video" do
      SiteSetting.voice_video_enabled = true
      room.update!(room_type: Voice::Room::ROOM_TYPE_STAGE, video_enabled: true)
      room.room_memberships.create!(user: user, role: Voice::RoomMembership::ROLE_SPEAKER)

      payload = decoded_token

      expect(payload["video"]["canPublish"]).to eq(true)
      expect(payload["video"]["canPublishSources"]).to eq(
        %w[microphone camera screen_share screen_share_audio],
      )
    end

    it "grants only the microphone to a stage speaker when the room has no video" do
      SiteSetting.voice_video_enabled = true
      room.update!(room_type: Voice::Room::ROOM_TYPE_STAGE, video_enabled: false)
      room.room_memberships.create!(user: user, role: Voice::RoomMembership::ROLE_SPEAKER)

      payload = decoded_token

      expect(payload["video"]["canPublish"]).to eq(true)
      expect(payload["video"]["canPublishSources"]).to eq(["microphone"])
    end
  end
end

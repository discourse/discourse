# frozen_string_literal: true

require "rails_helper"
require_relative "../../../../db/migrate/20241107000000_create_voice_rooms"
require_relative "../../../../db/migrate/20260305162426_add_room_type_to_voice_rooms"
require_relative "../../../../db/migrate/20260612135211_add_video_enabled_to_voice_rooms"

RSpec.describe Voice::Livekit::EgressClient do
  before do
    ActiveRecord::Migration.suppress_messages do
      CreateVoiceRooms.new.change unless ActiveRecord::Base.connection.table_exists?(:voice_rooms)
      unless ActiveRecord::Base.connection.column_exists?(:voice_rooms, :room_type)
        AddRoomTypeToVoiceRooms.new.change
      end
      unless ActiveRecord::Base.connection.column_exists?(:voice_rooms, :video_enabled)
        AddVideoEnabledToVoiceRooms.new.change
      end
    end
    Voice::Room.reset_column_information
    SiteSetting.voice_enabled = true
    SiteSetting.voice_livekit_url = "wss://livekit.example.com"
    SiteSetting.voice_livekit_api_key = "lk_api_key"
    SiteSetting.voice_livekit_api_secret = "lk_api_secret"
  end

  fab!(:room) { Fabricate(:voice_room, public: true) }

  def twirp_stub(method)
    stub_request(:post, "https://livekit.example.com/twirp/livekit.Egress/#{method}")
  end

  describe ".start_room_composite" do
    it "POSTs the room name and file output with a roomRecord-granted token" do
      SiteSetting.voice_video_enabled = false
      stub = twirp_stub("StartRoomCompositeEgress").to_return(body: { egressId: "EG_1" }.to_json)

      result = described_class.start_room_composite(room, filepath: "voice/test-abc123")

      expect(result).to eq(ok: true, data: { "egressId" => "EG_1" })
      expect(stub).to have_been_requested
      expect(
        a_request(
          :post,
          "https://livekit.example.com/twirp/livekit.Egress/StartRoomCompositeEgress",
        ).with do |req|
          body = JSON.parse(req.body)
          token = req.headers["Authorization"].delete_prefix("Bearer ")
          claims =
            JWT.decode(token, SiteSetting.voice_livekit_api_secret, true, algorithm: "HS256").first

          body ==
            {
              "roomName" => Voice::Livekit.room_name(room),
              "audioOnly" => true,
              "fileOutputs" => [{ "filepath" => "voice/test-abc123" }],
            } && claims["iss"] == "lk_api_key" && claims["video"] == { "roomRecord" => true }
        end,
      ).to have_been_made.once
    end

    it "requests a full composite for a room with video enabled" do
      SiteSetting.voice_video_enabled = true
      room.update!(video_enabled: true)
      twirp_stub("StartRoomCompositeEgress").to_return(body: "{}")

      described_class.start_room_composite(room, filepath: "voice/test-abc123")

      expect(
        a_request(
          :post,
          "https://livekit.example.com/twirp/livekit.Egress/StartRoomCompositeEgress",
        ).with { |req| JSON.parse(req.body)["audioOnly"] == false },
      ).to have_been_made.once
    end

    it "returns a structured error on an error response, without the upstream body" do
      upstream_body = "egress unavailable"
      twirp_stub("StartRoomCompositeEgress").to_return(status: 500, body: upstream_body)

      result = described_class.start_room_composite(room, filepath: "voice/test-abc123")

      expect(result[:ok]).to eq(false)
      expect(result[:error]).to eq("HTTP 500")
      expect(result[:error]).not_to include(upstream_body)
    end

    it "returns a structured error instead of raising on a timeout" do
      twirp_stub("StartRoomCompositeEgress").to_timeout

      result = described_class.start_room_composite(room, filepath: "voice/test-abc123")

      expect(result[:ok]).to eq(false)
    end

    it "makes zero HTTP calls when livekit is not configured" do
      stub = twirp_stub("StartRoomCompositeEgress")
      SiteSetting.voice_livekit_api_secret = ""

      result = described_class.start_room_composite(room, filepath: "voice/test-abc123")

      expect(result[:ok]).to eq(false)
      expect(stub).not_to have_been_requested
    end
  end

  describe ".stop" do
    it "POSTs the egress id and returns the parsed response" do
      stub =
        twirp_stub("StopEgress").with(body: { egressId: "EG_1" }.to_json).to_return(
          body: { egressId: "EG_1", status: "EGRESS_ENDING" }.to_json,
        )

      result = described_class.stop("EG_1")

      expect(stub).to have_been_requested
      expect(result).to eq(ok: true, data: { "egressId" => "EG_1", "status" => "EGRESS_ENDING" })
    end

    it "returns a structured error when the egress cannot be stopped" do
      twirp_stub("StopEgress").to_return(status: 404, body: "egress does not exist")

      result = described_class.stop("EG_missing")

      expect(result[:ok]).to eq(false)
      expect(result[:error]).to include("HTTP 404")
    end
  end

  describe ".list" do
    it "POSTs the egress id filter and returns the parsed items" do
      stub =
        twirp_stub("ListEgress").with(body: { egressId: "EG_1" }.to_json).to_return(
          body: { items: [{ egressId: "EG_1", status: "EGRESS_COMPLETE" }] }.to_json,
        )

      result = described_class.list(egress_id: "EG_1")

      expect(stub).to have_been_requested
      expect(result[:ok]).to eq(true)
      expect(result[:data]["items"].first["egressId"]).to eq("EG_1")
    end
  end
end

# frozen_string_literal: true

require "rails_helper"
require_relative "../../../../db/migrate/20241107000000_create_voice_rooms"
require_relative "../../../../db/migrate/20260305162426_add_room_type_to_voice_rooms"
require_relative "../../../../db/migrate/20260612135211_add_video_enabled_to_voice_rooms"

RSpec.describe Voice::Livekit::RoomServiceClient do
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
  end

  fab!(:user)
  fab!(:room) { Fabricate(:voice_room, public: true) }

  before do
    SiteSetting.voice_enabled = true
    SiteSetting.voice_livekit_url = "wss://livekit.example.com"
    SiteSetting.voice_livekit_api_key = "lk_api_key"
    SiteSetting.voice_livekit_api_secret = "lk_api_secret"
    Voice::ParticipantTracker.pin_transport!(room.id, "livekit")
  end

  after { Voice::ParticipantTracker.clear(room.id) }

  def twirp_stub(method)
    stub_request(:post, "https://livekit.example.com/twirp/livekit.RoomService/#{method}")
  end

  describe ".remove_participant" do
    it "POSTs the room name and identity with an admin bearer token" do
      stub = twirp_stub("RemoveParticipant")

      expect(described_class.remove_participant(room, user.id)).to eq(true)

      expect(stub).to have_been_requested
      expect(
        a_request(
          :post,
          "https://livekit.example.com/twirp/livekit.RoomService/RemoveParticipant",
        ).with do |req|
          body = JSON.parse(req.body)
          token = req.headers["Authorization"].delete_prefix("Bearer ")
          claims =
            JWT.decode(token, SiteSetting.voice_livekit_api_secret, true, algorithm: "HS256").first

          body == { "room" => Voice::Livekit.room_name(room), "identity" => user.id.to_s } &&
            req.headers["Content-Type"] == "application/json" && claims["iss"] == "lk_api_key" &&
            claims["video"] == { "roomAdmin" => true, "room" => Voice::Livekit.room_name(room) }
        end,
      ).to have_been_made.once
    end

    it "converts a ws:// url to http:// for the API endpoint" do
      SiteSetting.voice_livekit_url = "ws://livekit.internal:7880"
      stub =
        stub_request(
          :post,
          "http://livekit.internal:7880/twirp/livekit.RoomService/RemoveParticipant",
        )

      described_class.remove_participant(room, user.id)

      expect(stub).to have_been_requested
    end
  end

  describe ".update_participant" do
    before { SiteSetting.voice_video_enabled = true }

    it "sends the full permission set for a speaker in a video room" do
      room.update!(video_enabled: true)
      stub = twirp_stub("UpdateParticipant")

      described_class.update_participant(room, user)

      expect(stub).to have_been_requested
      expect(
        a_request(
          :post,
          "https://livekit.example.com/twirp/livekit.RoomService/UpdateParticipant",
        ).with do |req|
          body = JSON.parse(req.body)
          body["identity"] == user.id.to_s &&
            body["permission"] ==
              {
                "canSubscribe" => true,
                "canPublish" => true,
                "canPublishData" => false,
                "canPublishSources" => %w[MICROPHONE CAMERA SCREEN_SHARE SCREEN_SHARE_AUDIO],
                "hidden" => false,
                "recorder" => false,
              }
        end,
      ).to have_been_made.once
    end

    it "grants all publish sources to a stage speaker in a video room" do
      room.update!(room_type: Voice::Room::ROOM_TYPE_STAGE, video_enabled: true)
      room.room_memberships.create!(user: user, role: Voice::RoomMembership::ROLE_SPEAKER)
      twirp_stub("UpdateParticipant")

      described_class.update_participant(room, user)

      expect(
        a_request(
          :post,
          "https://livekit.example.com/twirp/livekit.RoomService/UpdateParticipant",
        ).with do |req|
          permission = JSON.parse(req.body)["permission"]
          permission["canPublish"] == true &&
            permission["canPublishSources"] == %w[MICROPHONE CAMERA SCREEN_SHARE SCREEN_SHARE_AUDIO]
        end,
      ).to have_been_made.once
    end

    it "keeps canSubscribe for a stage listener who cannot publish" do
      room.update!(room_type: Voice::Room::ROOM_TYPE_STAGE)
      stub = twirp_stub("UpdateParticipant")

      described_class.update_participant(room, user)

      expect(
        a_request(
          :post,
          "https://livekit.example.com/twirp/livekit.RoomService/UpdateParticipant",
        ).with do |req|
          permission = JSON.parse(req.body)["permission"]
          permission["canSubscribe"] == true && permission["canPublish"] == false &&
            permission["canPublishSources"] == []
        end,
      ).to have_been_made.once
    end
  end

  describe ".delete_room" do
    it "POSTs the room name with a roomCreate-granted token" do
      stub = twirp_stub("DeleteRoom").with(body: { room: Voice::Livekit.room_name(room) }.to_json)

      expect(described_class.delete_room(room)).to eq(true)

      expect(stub).to have_been_requested
      expect(
        a_request(
          :post,
          "https://livekit.example.com/twirp/livekit.RoomService/DeleteRoom",
        ).with do |req|
          token = req.headers["Authorization"].delete_prefix("Bearer ")
          claims =
            JWT.decode(token, SiteSetting.voice_livekit_api_secret, true, algorithm: "HS256").first

          # LiveKit authorizes DeleteRoom via roomCreate, not roomAdmin.
          claims["video"] == { "roomCreate" => true, "room" => Voice::Livekit.room_name(room) }
        end,
      ).to have_been_made.once
    end

    it "treats an already-deleted room as success without a warning" do
      twirp_stub("DeleteRoom").to_return(status: 404, body: "requested room does not exist")
      Rails.logger.expects(:warn).never

      expect(described_class.delete_room(room)).to eq(true)
    end
  end

  context "when the room is not pinned to livekit" do
    let!(:stub) { stub_request(:post, %r{\Ahttps://livekit\.example\.com/twirp/}) }

    it "makes zero HTTP calls for a mesh-pinned room" do
      Voice::ParticipantTracker.clear_transport_pin(room.id)
      Voice::ParticipantTracker.pin_transport!(room.id, "mesh")

      described_class.remove_participant(room, user.id)
      described_class.update_participant(room, user)
      described_class.delete_room(room)

      expect(stub).not_to have_been_requested
    end

    it "makes zero HTTP calls for an unpinned room" do
      Voice::ParticipantTracker.clear_transport_pin(room.id)

      described_class.delete_room(room)

      expect(stub).not_to have_been_requested
    end

    it "makes zero HTTP calls when livekit is no longer configured" do
      SiteSetting.voice_livekit_api_secret = ""

      described_class.delete_room(room)

      expect(stub).not_to have_been_requested
    end
  end

  context "when LiveKit is down" do
    it "never raises on a timeout and logs the failure" do
      twirp_stub("DeleteRoom").to_timeout
      Rails.logger.expects(:warn).with(regexp_matches(/\[voice-livekit\] DeleteRoom failed/))

      expect(described_class.delete_room(room)).to eq(false)
    end

    it "never raises on a refused connection" do
      twirp_stub("DeleteRoom").to_raise(Errno::ECONNREFUSED)

      expect { described_class.delete_room(room) }.not_to raise_error
    end

    it "still warns when a call other than DeleteRoom gets a 404" do
      twirp_stub("RemoveParticipant").to_return(status: 404, body: "participant does not exist")
      Rails
        .logger
        .expects(:warn)
        .with(regexp_matches(/\[voice-livekit\] RemoveParticipant failed.*HTTP 404/))

      expect(described_class.remove_participant(room, user.id)).to eq(false)
    end

    it "never raises on an error response and logs the failure" do
      twirp_stub("RemoveParticipant").to_return(status: 500, body: "internal error")
      Rails
        .logger
        .expects(:warn)
        .with(regexp_matches(/\[voice-livekit\] RemoveParticipant failed.*HTTP 500/))

      expect(described_class.remove_participant(room, user.id)).to eq(false)
    end
  end

  describe ".list_rooms" do
    it "keeps the upstream response body out of the probe result" do
      upstream_body = "upstream stack trace with internal hostnames"
      twirp_stub("ListRooms").to_return(status: 503, body: upstream_body)

      result = described_class.list_rooms

      expect(result[:ok]).to eq(false)
      expect(result[:error]).to eq("HTTP 503")
      expect(result[:error]).not_to include(upstream_body)
    end
  end

  context "when the URL resolves to a disallowed address" do
    it "refuses the connection and reports it without probing the host" do
      FinalDestination::TestHelper.stub_to_fail do
        result = described_class.list_rooms

        expect(result[:ok]).to eq(false)
        expect(result[:error]).to eq(
          "The LiveKit URL resolves to an address this server is not allowed to reach",
        )
      end
    end

    it "fails a sync call without raising" do
      FinalDestination::TestHelper.stub_to_fail do
        expect(described_class.remove_participant(room, user.id)).to eq(false)
      end
    end
  end
end

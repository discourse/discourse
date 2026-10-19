# frozen_string_literal: true

require "rails_helper"
require_relative "../../../../db/migrate/20241107000000_create_voice_rooms"
require_relative "../../../../db/migrate/20260305162426_add_room_type_to_voice_rooms"
require_relative "../../../../db/migrate/20260612135211_add_video_enabled_to_voice_rooms"
require_relative "../../../../db/migrate/20260717172530_create_voice_recordings"

RSpec.describe Jobs::Voice::ReconcileRecordings do
  before do
    ActiveRecord::Migration.suppress_messages do
      CreateVoiceRooms.new.change unless ActiveRecord::Base.connection.table_exists?(:voice_rooms)
      unless ActiveRecord::Base.connection.column_exists?(:voice_rooms, :room_type)
        AddRoomTypeToVoiceRooms.new.change
      end
      unless ActiveRecord::Base.connection.column_exists?(:voice_rooms, :video_enabled)
        AddVideoEnabledToVoiceRooms.new.change
      end
      unless ActiveRecord::Base.connection.table_exists?(:voice_recordings)
        CreateVoiceRecordings.new.change
      end
    end
    Voice::Room.reset_column_information
    Voice::Recording.reset_column_information
  end

  fab!(:user)
  fab!(:room) { Fabricate(:voice_room, public: true) }

  before do
    SiteSetting.voice_enabled = true
    SiteSetting.voice_livekit_url = "wss://livekit.example.com"
    SiteSetting.voice_livekit_api_key = "lk_api_key"
    SiteSetting.voice_livekit_api_secret = "lk_api_secret"
    SiteSetting.voice_livekit_recording_enabled = true
  end

  def create_stuck_recording
    Voice::Recording.create!(
      room: room,
      started_by: user,
      egress_id: "EG_1",
      filepath: "voice/test-abc123",
      started_at: 10.minutes.ago,
    )
  end

  let!(:list_stub) do
    stub_request(:post, "https://livekit.example.com/twirp/livekit.Egress/ListEgress").to_return(
      body: {
        items: [
          {
            "egressId" => "EG_1",
            "status" => "EGRESS_COMPLETE",
            "fileResults" => [{ "filename" => "test.mp4" }],
          },
        ],
      }.to_json,
    )
  end

  it "resolves stuck recordings without webhooks" do
    recording = create_stuck_recording

    described_class.new.execute({})

    expect(recording.reload.status).to eq("completed")
    expect(list_stub).to have_been_requested
  end

  it "makes zero HTTP calls when there is nothing to resolve" do
    described_class.new.execute({})

    expect(list_stub).not_to have_been_requested
  end

  it "makes zero HTTP calls when recordings are disabled" do
    create_stuck_recording
    SiteSetting.voice_livekit_recording_enabled = false

    described_class.new.execute({})

    expect(list_stub).not_to have_been_requested
  end

  it "makes zero HTTP calls when LiveKit is not configured" do
    create_stuck_recording
    SiteSetting.voice_livekit_api_secret = ""

    described_class.new.execute({})

    expect(list_stub).not_to have_been_requested
  end
end

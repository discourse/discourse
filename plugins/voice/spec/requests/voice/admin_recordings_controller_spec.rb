# frozen_string_literal: true

require "rails_helper"
require_relative "../../../db/migrate/20241107000000_create_voice_rooms"
require_relative "../../../db/migrate/20260305162426_add_room_type_to_voice_rooms"
require_relative "../../../db/migrate/20260612135211_add_video_enabled_to_voice_rooms"
require_relative "../../../db/migrate/20260717172530_create_voice_recordings"

RSpec.describe Voice::AdminRecordingsController do
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
    SiteSetting.voice_enabled = true
  end

  fab!(:admin)
  fab!(:user)
  fab!(:room) { Fabricate(:voice_room, public: true) }

  fab!(:recording) do
    Voice::Recording.create!(
      room: room,
      started_by: user,
      egress_id: "EG_1",
      status: :completed,
      filepath: "voice/test-abc123",
      location: "https://cdn.example.com/voice/test-abc123.mp4",
      duration_ms: 65_000,
      started_at: 1.hour.ago,
      ended_at: 59.minutes.ago,
    )
  end

  describe "#index" do
    it "lists recordings newest-first with room, requester, and file details for admins" do
      Voice::Recording.create!(
        room: room,
        started_by: user,
        egress_id: "EG_2",
        filepath: "voice/test-def456",
        started_at: 5.minutes.ago,
      )
      sign_in(admin)

      get "/admin/plugins/voice/recordings.json"

      expect(response.status).to eq(200)
      payload = response.parsed_body
      expect(payload["has_more"]).to eq(false)
      expect(payload["recordings"].map { |row| row["egress_id"] }).to eq(%w[EG_2 EG_1])

      completed = payload["recordings"].last
      expect(completed["room_name"]).to eq(room.name)
      expect(completed["started_by"]["username"]).to eq(user.username)
      expect(completed["status"]).to eq("completed")
      expect(completed["location"]).to eq("https://cdn.example.com/voice/test-abc123.mp4")
      expect(completed["duration_ms"]).to eq(65_000)
    end

    it "paginates past the page size" do
      stub_const(Voice::AdminRecordingsController, "PAGE_SIZE", 1) do
        sign_in(admin)
        Voice::Recording.create!(
          room: room,
          started_by: user,
          egress_id: "EG_2",
          filepath: "voice/test-def456",
          started_at: 5.minutes.ago,
        )

        get "/admin/plugins/voice/recordings.json"
        expect(response.parsed_body["has_more"]).to eq(true)
        expect(response.parsed_body["recordings"].size).to eq(1)

        get "/admin/plugins/voice/recordings.json?offset=1"
        expect(response.parsed_body["has_more"]).to eq(false)
        expect(response.parsed_body["recordings"].map { |row| row["egress_id"] }).to eq(["EG_1"])
      end
    end

    it "is not available to regular users" do
      sign_in(user)

      get "/admin/plugins/voice/recordings.json"

      expect(response.status).to eq(404)
    end
  end
end

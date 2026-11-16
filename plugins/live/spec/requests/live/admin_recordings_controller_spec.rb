# frozen_string_literal: true

require "rails_helper"

RSpec.describe Live::AdminRecordingsController do
  fab!(:admin)
  fab!(:user)
  fab!(:room) { Fabricate(:live_room, public: true) }

  fab!(:recording) do
    Live::Recording.create!(
      room: room,
      started_by: user,
      egress_id: "EG_1",
      status: :completed,
      filepath: "live/test-abc123",
      location: "https://cdn.example.com/live/test-abc123.mp4",
      duration_ms: 65_000,
      started_at: 1.hour.ago,
      ended_at: 59.minutes.ago,
    )
  end

  before { SiteSetting.live_enabled = true }

  describe "#index" do
    it "lists recordings newest-first with room, requester, and file details for admins" do
      Live::Recording.create!(
        room: room,
        started_by: user,
        egress_id: "EG_2",
        filepath: "live/test-def456",
        started_at: 5.minutes.ago,
      )
      sign_in(admin)

      get "/admin/plugins/live/recordings.json"

      expect(response.status).to eq(200)
      payload = response.parsed_body
      expect(payload["has_more"]).to eq(false)
      expect(payload["last_webhook_at"]).to be_nil
      expect(payload["webhook_url"]).to eq("#{Discourse.base_url}/live/livekit/webhook")
      expect(payload["recordings"].map { |row| row["egress_id"] }).to eq(%w[EG_2 EG_1])

      completed = payload["recordings"].last
      expect(completed["room_name"]).to eq(room.name)
      expect(completed["started_by"]["username"]).to eq(user.username)
      expect(completed["status"]).to eq("completed")
      expect(completed["location"]).to eq("https://cdn.example.com/live/test-abc123.mp4")
      expect(completed["duration_ms"]).to eq(65_000)
    end

    it "reports received webhooks so the setup note can be hidden" do
      freeze_time
      Live::Livekit.touch_last_webhook!
      sign_in(admin)

      get "/admin/plugins/live/recordings.json"

      expect(Time.iso8601(response.parsed_body["last_webhook_at"]).to_i).to eq(Time.current.to_i)
    end

    it "paginates past the page size" do
      stub_const(Live::AdminRecordingsController, "PAGE_SIZE", 1) do
        sign_in(admin)
        Live::Recording.create!(
          room: room,
          started_by: user,
          egress_id: "EG_2",
          filepath: "live/test-def456",
          started_at: 5.minutes.ago,
        )

        get "/admin/plugins/live/recordings.json"
        expect(response.parsed_body["has_more"]).to eq(true)
        expect(response.parsed_body["recordings"].size).to eq(1)

        get "/admin/plugins/live/recordings.json?offset=1"
        expect(response.parsed_body["has_more"]).to eq(false)
        expect(response.parsed_body["recordings"].map { |row| row["egress_id"] }).to eq(["EG_1"])
      end
    end

    it "is not available to regular users" do
      sign_in(user)

      get "/admin/plugins/live/recordings.json"

      expect(response.status).to eq(404)
    end
  end
end

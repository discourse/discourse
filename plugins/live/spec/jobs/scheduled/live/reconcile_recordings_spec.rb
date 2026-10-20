# frozen_string_literal: true

require "rails_helper"

RSpec.describe Jobs::Live::ReconcileRecordings do
  fab!(:user)
  fab!(:room) { Fabricate(:live_room, public: true) }

  before do
    SiteSetting.live_enabled = true
    SiteSetting.live_livekit_url = "wss://livekit.example.com"
    SiteSetting.live_livekit_api_key = "lk_api_key"
    SiteSetting.live_livekit_api_secret = "lk_api_secret"
    SiteSetting.live_livekit_recording_enabled = true
  end

  def create_stuck_recording
    Live::Recording.create!(
      room: room,
      started_by: user,
      egress_id: "EG_1",
      filepath: "live/test-abc123",
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
    SiteSetting.live_livekit_recording_enabled = false

    described_class.new.execute({})

    expect(list_stub).not_to have_been_requested
  end

  it "makes zero HTTP calls when LiveKit is not configured" do
    create_stuck_recording
    SiteSetting.live_livekit_api_secret = ""

    described_class.new.execute({})

    expect(list_stub).not_to have_been_requested
  end
end

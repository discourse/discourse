# frozen_string_literal: true

require "rails_helper"

RSpec.describe Jobs::VoiceLivekitProbe do
  before do
    SiteSetting.voice_enabled = true
    SiteSetting.voice_livekit_url = "wss://livekit.example.com"
    SiteSetting.voice_livekit_api_key = "lk_api_key"
    SiteSetting.voice_livekit_api_secret = "lk_api_secret"
  end

  after { Voice::Livekit::HealthCheck.clear_probe! }

  def list_rooms_stub
    stub_request(:post, "https://livekit.example.com/twirp/livekit.RoomService/ListRooms")
  end

  it "stores a passing result when the server is reachable" do
    list_rooms_stub.to_return(status: 200, body: { rooms: [{ name: "default-r1" }] }.to_json)

    described_class.new.execute({})

    probe = Voice::Livekit::HealthCheck.last_probe
    expect(probe[:ok]).to eq(true)
    expect(probe[:token][:ok]).to eq(true)
    expect(probe[:server][:ok]).to eq(true)
    expect(probe[:server][:room_count]).to eq(1)
    expect(probe[:checked_at]).to be_present
  end

  it "stores the failure and logs it with the [voice-livekit] prefix" do
    list_rooms_stub.to_timeout
    Rails.logger.expects(:warn).with(regexp_matches(/\[voice-livekit\] connectivity probe failed/))

    described_class.new.execute({})

    probe = Voice::Livekit::HealthCheck.last_probe
    expect(probe[:ok]).to eq(false)
    expect(probe[:server][:ok]).to eq(false)
    expect(probe[:server][:error]).to be_present
  end

  it "drops the stored result instead of probing when LiveKit was deconfigured" do
    Voice::Livekit::HealthCheck.store_probe!(ok: true)
    SiteSetting.voice_livekit_api_secret = ""
    probe_stub = stub_request(:post, %r{\Ahttps://})

    described_class.new.execute({})

    expect(Voice::Livekit::HealthCheck.last_probe).to be_nil
    expect(probe_stub).not_to have_been_requested
  end

  describe "enqueueing" do
    it "is enqueued when a LiveKit setting changes" do
      expect_enqueued_with(job: :voice_livekit_probe) do
        SiteSetting.voice_livekit_url = "wss://other.example.com"
      end
    end

    it "is enqueued when the room policy changes" do
      expect_enqueued_with(job: :voice_livekit_probe) do
        SiteSetting.voice_livekit_room_policy = "all_rooms"
      end
    end

    it "is enqueued when the mesh fallback changes" do
      expect_enqueued_with(job: :voice_livekit_probe) do
        SiteSetting.voice_livekit_mesh_fallback = true
      end
    end

    it "is not enqueued for unrelated settings" do
      expect_not_enqueued_with(job: :voice_livekit_probe) do
        SiteSetting.voice_max_rooms_per_user = 6
      end
    end
  end
end

# frozen_string_literal: true

require "rails_helper"
require_relative "../../../db/migrate/20241107000000_create_voice_rooms"
require_relative "../../../db/migrate/20260305162426_add_room_type_to_voice_rooms"
require_relative "../../../db/migrate/20260612135211_add_video_enabled_to_voice_rooms"
require_relative "../../../db/migrate/20260717172530_create_voice_recordings"

RSpec.describe Voice::RecordingManager do
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

  fab!(:moderator, :user)
  fab!(:room) { Fabricate(:voice_room, public: true) }

  before do
    SiteSetting.voice_enabled = true
    SiteSetting.voice_livekit_url = "wss://livekit.example.com"
    SiteSetting.voice_livekit_api_key = "lk_api_key"
    SiteSetting.voice_livekit_api_secret = "lk_api_secret"
    SiteSetting.voice_livekit_recording_enabled = true
    Voice::ParticipantTracker.pin_transport!(room.id, "livekit")
  end

  after { Voice::ParticipantTracker.clear(room.id) }

  def stub_start(egress_id: "EG_1", status: 200, response_key: "egressId")
    stub_request(
      :post,
      "https://livekit.example.com/twirp/livekit.Egress/StartRoomCompositeEgress",
    ).to_return(status: status, body: { response_key => egress_id }.to_json)
  end

  def stub_stop(status: 200)
    stub_request(:post, "https://livekit.example.com/twirp/livekit.Egress/StopEgress").to_return(
      status: status,
      body: "{}",
    )
  end

  def egress_info(egress_id: "EG_1", error: nil, file: :default)
    file = { "filename" => "test.mp4", "location" => nil } if file == :default
    info = { "egressId" => egress_id, "status" => "EGRESS_COMPLETE" }
    info["error"] = error if error
    info["fileResults"] = [file] if file
    info
  end

  describe ".start!" do
    it "starts an egress, persists a recording row with a tokenized filepath, and broadcasts" do
      stub_start

      messages =
        MessageBus.track_publish(Voice.room_channel(room.id)) do
          result = described_class.start!(room, moderator)
          expect(result[:started_by]).to eq(id: moderator.id, username: moderator.username)
        end

      recording = Voice::Recording.find_by(egress_id: "EG_1")
      expect(recording.room_id).to eq(room.id)
      expect(recording.started_by_id).to eq(moderator.id)
      expect(recording.status).to eq("recording")
      expect(recording.filepath).to match(
        /\A#{Regexp.escape(SiteSetting.voice_livekit_recording_filepath)}-\h{16}\z/,
      )

      recording_messages = messages.select { |message| message.data[:type] == "recording" }
      expect(recording_messages.size).to eq(1)
      expect(recording_messages.first.data[:recording][:started_by][:id]).to eq(moderator.id)
    end

    it "sends the tokenized filepath to the egress service" do
      stub_start

      described_class.start!(room, moderator)

      filepath = Voice::Recording.find_by(egress_id: "EG_1").filepath
      expect(
        a_request(
          :post,
          "https://livekit.example.com/twirp/livekit.Egress/StartRoomCompositeEgress",
        ).with { |req| JSON.parse(req.body)["fileOutputs"] == [{ "filepath" => filepath }] },
      ).to have_been_made.once
    end

    it "persists the egress ID from a snake_case API response" do
      stub_start(response_key: "egress_id")

      described_class.start!(room, moderator)

      expect(Voice::Recording.find_by(egress_id: "EG_1")).to be_present
    end

    it "refuses when recordings are disabled" do
      SiteSetting.voice_livekit_recording_enabled = false

      expect { described_class.start!(room, moderator) }.to raise_error(
        described_class::Error,
        I18n.t("voice.errors.recording_unavailable"),
      )
    end

    it "refuses for a call not pinned to livekit" do
      Voice::ParticipantTracker.clear_transport_pin(room.id)
      Voice::ParticipantTracker.pin_transport!(room.id, "mesh")

      expect { described_class.start!(room, moderator) }.to raise_error(
        described_class::Error,
        I18n.t("voice.errors.recording_unavailable"),
      )
    end

    it "refuses when a recording is already running" do
      stub_start
      described_class.start!(room, moderator)

      expect { described_class.start!(room, moderator) }.to raise_error(
        described_class::Error,
        I18n.t("voice.errors.recording_already_active"),
      )
    end

    it "persists nothing and broadcasts nothing when the egress fails to start" do
      stub_start(status: 500)

      messages =
        MessageBus.track_publish(Voice.room_channel(room.id)) do
          expect { described_class.start!(room, moderator) }.to raise_error(
            described_class::Error,
            I18n.t("voice.errors.recording_failed"),
          )
        end

      expect(described_class.status(room.id)).to be_nil
      expect(Voice::Recording.count).to eq(0)
      expect(messages).to be_empty
    end
  end

  describe ".stop!" do
    it "stops the egress, clears the live state, and broadcasts the end" do
      stub_start
      described_class.start!(room, moderator)
      stub_stop

      messages =
        MessageBus.track_publish(Voice.room_channel(room.id)) { described_class.stop!(room) }

      expect(described_class.status(room.id)).to be_nil
      recording_messages = messages.select { |message| message.data[:type] == "recording" }
      expect(recording_messages.size).to eq(1)
      expect(recording_messages.first.data[:recording]).to be_nil
    end

    it "refuses when nothing is being recorded" do
      expect { described_class.stop!(room) }.to raise_error(
        described_class::Error,
        I18n.t("voice.errors.recording_not_active"),
      )
    end

    it "keeps the state when the egress cannot be stopped" do
      stub_start
      described_class.start!(room, moderator)
      stub_stop(status: 500)

      expect { described_class.stop!(room) }.to raise_error(
        described_class::Error,
        I18n.t("voice.errors.recording_stop_failed"),
      )
      expect(described_class.status(room.id)).to be_present
    end
  end

  describe ".handle_egress_ended" do
    it "completes the row, clears the live state, broadcasts, and PMs the requester a link" do
      stub_start
      described_class.start!(room, moderator)

      file = {
        "filename" => "voice/watercooler.mp4",
        "location" => "https://cdn.example.com/voice/watercooler.mp4",
        "duration" => (65 * 1_000_000_000).to_s,
        "size" => "12345678",
      }

      messages =
        MessageBus.track_publish(Voice.room_channel(room.id)) do
          described_class.handle_egress_ended(room, egress_info(file: file))
        end

      recording = Voice::Recording.find_by(egress_id: "EG_1")
      expect(recording.status).to eq("completed")
      expect(recording.location).to eq("https://cdn.example.com/voice/watercooler.mp4")
      expect(recording.duration_ms).to eq(65_000)
      expect(recording.size_bytes).to eq(12_345_678)
      expect(recording.ended_at).to be_present

      expect(described_class.status(room.id)).to be_nil
      expect(messages.map { |message| message.data[:type] }).to include("recording")

      pm_topic =
        Topic.private_messages_for_user(moderator).find_by(
          title: I18n.t("voice.recording_ready_pm.title", room_name: room.name),
        )
      expect(pm_topic).to be_present
      expect(pm_topic.first_post.raw).to include(
        "https://cdn.example.com/voice/watercooler.mp4",
      ).and include("1:05")
    end

    it "PMs the storage path when the egress reports no URL" do
      stub_start
      described_class.start!(room, moderator)
      recording = Voice::Recording.find_by(egress_id: "EG_1")

      described_class.handle_egress_ended(room, egress_info)

      pm_topic =
        Topic.private_messages_for_user(moderator).find_by(
          title: I18n.t("voice.recording_ready_pm.title", room_name: room.name),
        )
      expect(pm_topic.first_post.raw).to include(recording.filepath)
    end

    it "marks the row failed and sends no PM when the egress reports an error" do
      stub_start
      described_class.start!(room, moderator)

      described_class.handle_egress_ended(room, egress_info(error: "could not connect", file: nil))

      expect(Voice::Recording.find_by(egress_id: "EG_1").status).to eq("failed")
      expect(Topic.private_messages_for_user(moderator)).to be_empty
    end

    it "finalizes a recording from a snake_case egress response" do
      stub_start
      described_class.start!(room, moderator)

      described_class.handle_egress_ended(
        room,
        {
          "egress_id" => "EG_1",
          "status" => "EGRESS_COMPLETE",
          "file_results" => [{ "filename" => "test.mp4", "location" => nil }],
        },
      )

      expect(Voice::Recording.find_by(egress_id: "EG_1")).to be_completed
    end

    it "finalizes the row even when the live room state is already gone" do
      stub_start
      described_class.start!(room, moderator)
      Voice::ParticipantTracker.clear_transport_pin(room.id)

      described_class.handle_egress_ended(room, egress_info)

      expect(Voice::Recording.find_by(egress_id: "EG_1").status).to eq("completed")
      expect(Topic.private_messages_for_user(moderator).count).to eq(1)
    end

    it "ignores an egress that was never tracked" do
      messages =
        MessageBus.track_publish(Voice.room_channel(room.id)) do
          described_class.handle_egress_ended(room, egress_info(egress_id: "EG_unknown"))
        end

      expect(messages).to be_empty
      expect(Voice::Recording.count).to eq(0)
    end

    it "does not finalize twice or resend the PM for an already-finalized egress" do
      stub_start
      described_class.start!(room, moderator)
      described_class.handle_egress_ended(room, egress_info)

      described_class.handle_egress_ended(room, egress_info)

      expect(Topic.private_messages_for_user(moderator).count).to eq(1)
    end
  end

  describe ".reconcile_pending!" do
    def stub_list(items:)
      stub_request(:post, "https://livekit.example.com/twirp/livekit.Egress/ListEgress").to_return(
        body: { items: items }.to_json,
      )
    end

    it "finalizes a stuck row, PMs the requester, and clears the live state" do
      stub_start
      described_class.start!(room, moderator)
      stub_list(
        items: [
          {
            "egressId" => "EG_1",
            "status" => "EGRESS_COMPLETE",
            "fileResults" => [
              { "filename" => "test.mp4", "location" => "https://cdn.example.com/test.mp4" },
            ],
          },
        ],
      )

      described_class.reconcile_pending!

      recording = Voice::Recording.find_by(egress_id: "EG_1")
      expect(recording.status).to eq("completed")
      expect(recording.location).to eq("https://cdn.example.com/test.mp4")
      expect(described_class.status(room.id)).to be_nil
      expect(Topic.private_messages_for_user(moderator).count).to eq(1)
    end

    it "leaves a still-active egress alone" do
      stub_start
      described_class.start!(room, moderator)
      stub_list(items: [{ "egressId" => "EG_1", "status" => "EGRESS_ACTIVE" }])

      described_class.reconcile_pending!

      expect(Voice::Recording.find_by(egress_id: "EG_1").status).to eq("recording")
      expect(described_class.status(room.id)).to be_present
    end

    it "writes off an old row the egress service no longer remembers, without a PM" do
      stub_start
      described_class.start!(room, moderator)
      Voice::Recording.find_by(egress_id: "EG_1").update!(started_at: 25.hours.ago)
      stub_list(items: [])

      described_class.reconcile_pending!

      expect(Voice::Recording.find_by(egress_id: "EG_1").status).to eq("failed")
      expect(Topic.private_messages_for_user(moderator)).to be_empty
    end

    it "keeps a recent row the egress service did not return yet" do
      stub_start
      described_class.start!(room, moderator)
      stub_list(items: [])

      described_class.reconcile_pending!

      expect(Voice::Recording.find_by(egress_id: "EG_1").status).to eq("recording")
    end

    it "keeps a stuck row when the egress service is unreachable" do
      stub_start
      described_class.start!(room, moderator)
      stub_request(:post, "https://livekit.example.com/twirp/livekit.Egress/ListEgress").to_timeout

      expect { described_class.reconcile_pending! }.not_to raise_error
      expect(Voice::Recording.find_by(egress_id: "EG_1").status).to eq("recording")
    end
  end

  it "clears the live recording state together with the transport pin" do
    stub_start
    described_class.start!(room, moderator)

    Voice::ParticipantTracker.clear_transport_pin(room.id)

    expect(described_class.status(room.id)).to be_nil
  end
end

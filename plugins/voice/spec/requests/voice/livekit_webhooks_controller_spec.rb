# frozen_string_literal: true

require "rails_helper"
require_relative "../../../db/migrate/20241107000000_create_voice_rooms"
require_relative "../../../db/migrate/20260305162426_add_room_type_to_voice_rooms"
require_relative "../../../db/migrate/20260612135211_add_video_enabled_to_voice_rooms"
require_relative "../../../db/migrate/20260630183841_add_chat_settings_to_voice_rooms"
require_relative "../../../db/migrate/20260709165411_add_livekit_enabled_to_voice_rooms"
require_relative "../../../db/migrate/20260717172530_create_voice_recordings"

RSpec.describe Voice::LivekitWebhooksController do
  before do
    ActiveRecord::Migration.suppress_messages do
      CreateVoiceRooms.new.change unless ActiveRecord::Base.connection.table_exists?(:voice_rooms)
      unless ActiveRecord::Base.connection.column_exists?(:voice_rooms, :room_type)
        AddRoomTypeToVoiceRooms.new.change
      end
      unless ActiveRecord::Base.connection.column_exists?(:voice_rooms, :video_enabled)
        AddVideoEnabledToVoiceRooms.new.change
      end
      unless ActiveRecord::Base.connection.column_exists?(:voice_rooms, :chat_channel_id)
        AddChatSettingsToVoiceRooms.new.change
      end
      unless ActiveRecord::Base.connection.column_exists?(:voice_rooms, :livekit_enabled)
        AddLivekitEnabledToVoiceRooms.new.change
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
    SiteSetting.voice_allowed_groups =
      "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"
    SiteSetting.voice_livekit_url = "wss://livekit.example.com"
    SiteSetting.voice_livekit_api_key = "lk_api_key"
    SiteSetting.voice_livekit_api_secret = "lk_api_secret"
    SiteSetting.voice_livekit_room_policy = "all_rooms"
  end

  after do
    Voice::ParticipantTracker.clear(room.id)
    Discourse.redis.del(Voice::Livekit::LAST_WEBHOOK_KEY)
  end

  def signed_headers(body, secret: "lk_api_secret", key: "lk_api_key", sha256: nil, exp: nil)
    token =
      JWT.encode(
        {
          iss: key,
          exp: (exp || 1.minute.from_now).to_i,
          sha256: sha256 || Digest::SHA256.base64digest(body),
        },
        secret,
        "HS256",
      )
    { "Authorization" => token, "CONTENT_TYPE" => "application/webhook+json" }
  end

  # `created_at` defaults to the future so presence added a moment earlier in
  # the test always counts as seen before the event.
  def event_for(
    event: "participant_left",
    room_name: Voice::Livekit.room_name(room),
    identity: user.id.to_s,
    sid: "PA_test",
    created_at: 1.minute.from_now
  )
    {
      "event" => event,
      "id" => "EV_test",
      "createdAt" => created_at.to_i.to_s,
      "room" => {
        "sid" => "RM_test",
        "name" => room_name,
      },
      "participant" => {
        "sid" => sid,
        "identity" => identity,
      },
    }
  end

  def post_webhook(event = event_for, headers: nil)
    body = event.to_json
    post "/voice/livekit/webhook", params: body, headers: headers || signed_headers(body)
  end

  describe "#create" do
    context "with an invalid delivery" do
      it "rejects a request with no Authorization token and records no delivery" do
        body = event_for.to_json

        post "/voice/livekit/webhook",
             params: body,
             headers: {
               "CONTENT_TYPE" => "application/webhook+json",
             }

        expect(response.status).to eq(403)
        expect(Voice::Livekit.last_webhook_at).to be_nil
      end

      it "rejects a token signed with the wrong secret" do
        body = event_for.to_json

        post "/voice/livekit/webhook",
             params: body,
             headers: signed_headers(body, secret: "not-the-secret")

        expect(response.status).to eq(403)
      end

      it "rejects an expired token" do
        body = event_for.to_json

        post "/voice/livekit/webhook",
             params: body,
             headers: signed_headers(body, exp: 1.minute.ago)

        expect(response.status).to eq(403)
      end

      it "rejects a token issued for a different API key" do
        body = event_for.to_json

        post "/voice/livekit/webhook", params: body, headers: signed_headers(body, key: "other")

        expect(response.status).to eq(403)
      end

      it "rejects a body that does not match the signed hash" do
        signed_body = event_for.to_json
        tampered_body = event_for(identity: "999").to_json

        post "/voice/livekit/webhook", params: tampered_body, headers: signed_headers(signed_body)

        expect(response.status).to eq(403)
        expect(Voice::ParticipantTracker.pinned_transport(room.id)).to be_nil
      end

      it "rejects everything when LiveKit is unconfigured" do
        body = event_for.to_json
        headers = signed_headers(body)
        SiteSetting.voice_livekit_api_secret = ""

        post "/voice/livekit/webhook", params: body, headers: headers

        expect(response.status).to eq(403)
      end
    end

    it "records the delivery time of every verified webhook, including unhandled events" do
      post_webhook(event_for(event: "room_started"))

      expect(response.status).to eq(200)
      expect(Voice::Livekit.last_webhook_at).to be_within(5.seconds).of(Time.now)
    end

    %w[participant_left participant_connection_aborted].each do |event_name|
      context "with a #{event_name} event" do
        it "expires the participant's presence, keeps their metadata, and broadcasts the change" do
          Voice::ParticipantTracker.pin_transport!(room.id, "livekit")
          Voice::ParticipantTracker.add(room.id, user.id)
          Voice::ParticipantTracker.update_metadata(room.id, user.id, { role: "participant" })

          messages =
            MessageBus.track_publish(Voice.room_channel(room.id)) do
              post_webhook(event_for(event: event_name))
            end

          expect(response.status).to eq(200)
          expect(Voice::ParticipantTracker.user_ids(room.id)).not_to include(user.id)
          expect(Voice::ParticipantTracker.get_metadata(room.id, user.id)[:role]).to eq(
            "participant",
          )
          expect(messages.map { |message| message.data[:type] }).to include("participants")
        end
      end
    end

    context "with a participant_left event" do
      it "leaves presence alone when it was refreshed after the event fired" do
        Voice::ParticipantTracker.pin_transport!(room.id, "livekit")
        Voice::ParticipantTracker.add(room.id, user.id)

        post_webhook(event_for(created_at: 2.minutes.ago))

        expect(response.status).to eq(200)
        expect(Voice::ParticipantTracker.user_ids(room.id)).to include(user.id)
      end

      it "never creates presence for a participant who is not in the room" do
        Voice::ParticipantTracker.pin_transport!(room.id, "livekit")

        post_webhook

        expect(response.status).to eq(200)
        expect(Voice::ParticipantTracker.user_ids(room.id)).to be_empty
      end

      it "ignores rooms pinned to mesh" do
        Voice::ParticipantTracker.pin_transport!(room.id, "mesh")
        Voice::ParticipantTracker.add(room.id, user.id)

        post_webhook

        expect(response.status).to eq(200)
        expect(Voice::ParticipantTracker.user_ids(room.id)).to include(user.id)
      end

      it "ignores rooms with no pinned transport" do
        Voice::ParticipantTracker.add(room.id, user.id)

        post_webhook

        expect(response.status).to eq(200)
        expect(Voice::ParticipantTracker.user_ids(room.id)).to include(user.id)
      end

      it "ignores events for rooms outside this site's namespace" do
        Voice::ParticipantTracker.pin_transport!(room.id, "livekit")
        Voice::ParticipantTracker.add(room.id, user.id)

        post_webhook(event_for(room_name: "othersite-r#{room.id}"))

        expect(response.status).to eq(200)
        expect(Voice::ParticipantTracker.user_ids(room.id)).to include(user.id)
      end

      it "ignores a non-numeric participant identity" do
        Voice::ParticipantTracker.pin_transport!(room.id, "livekit")
        Voice::ParticipantTracker.add(room.id, user.id)

        post_webhook(event_for(identity: "recorder-bot"))

        expect(response.status).to eq(200)
        expect(Voice::ParticipantTracker.user_ids(room.id)).to include(user.id)
      end

      it "leaves the session row open for CloseOrphanedSessions to close" do
        sign_in(user)
        post "/voice/rooms/#{room.id}/join.json"
        expect(response.status).to eq(200)
        session = Voice::Session.find_by(user_id: user.id, room_id: room.id)

        post_webhook

        expect(response.status).to eq(200)
        expect(Voice::ParticipantTracker.user_ids(room.id)).not_to include(user.id)
        expect(session.reload.left_at).to be_nil

        Jobs::Voice::CloseOrphanedSessions.new.execute({})

        expect(session.reload.left_at).to be_present
      end
    end

    context "with a rejoined participant" do
      before do
        Voice::ParticipantTracker.pin_transport!(room.id, "livekit")
        Voice::ParticipantTracker.add(room.id, user.id)
      end

      it "ignores the superseded session's late departure" do
        post_webhook(event_for(event: "participant_joined", sid: "PA_new"))
        post_webhook(event_for(sid: "PA_old"))

        expect(response.status).to eq(200)
        expect(Voice::ParticipantTracker.user_ids(room.id)).to include(user.id)
      end

      it "expires presence when the departing session is the recorded one" do
        post_webhook(event_for(event: "participant_joined", sid: "PA_new"))
        post_webhook(event_for(sid: "PA_new"))

        expect(response.status).to eq(200)
        expect(Voice::ParticipantTracker.user_ids(room.id)).not_to include(user.id)
      end

      it "expires presence when no session was recorded for the user" do
        post_webhook(event_for(sid: "PA_old"))

        expect(response.status).to eq(200)
        expect(Voice::ParticipantTracker.user_ids(room.id)).not_to include(user.id)
      end
    end

    context "with a room_finished event" do
      it "clears the transport pin of a livekit room without touching presence" do
        Voice::ParticipantTracker.pin_transport!(room.id, "livekit")
        Voice::ParticipantTracker.add(room.id, user.id)

        post_webhook(event_for(event: "room_finished"))

        expect(response.status).to eq(200)
        expect(Voice::ParticipantTracker.pinned_transport(room.id)).to be_nil
        expect(Voice::ParticipantTracker.user_ids(room.id)).to include(user.id)
      end

      it "keeps a mesh room's pin" do
        Voice::ParticipantTracker.pin_transport!(room.id, "mesh")

        post_webhook(event_for(event: "room_finished"))

        expect(response.status).to eq(200)
        expect(Voice::ParticipantTracker.pinned_transport(room.id)).to eq("mesh")
      end
    end

    context "with an egress_ended event" do
      def egress_event(
        egress_id: "EG_1",
        room_name: Voice::Livekit.room_name(room),
        snake_case: false
      )
        egress_info =
          if snake_case
            { "egress_id" => egress_id, "room_name" => room_name, "status" => "EGRESS_COMPLETE" }
          else
            { "egressId" => egress_id, "roomName" => room_name, "status" => "EGRESS_COMPLETE" }
          end

        event = {
          "event" => "egress_ended",
          "id" => "EV_egress",
          "createdAt" => 1.minute.from_now.to_i.to_s,
        }
        event[snake_case ? "egress_info" : "egressInfo"] = egress_info
        event
      end

      before do
        Voice::ParticipantTracker.pin_transport!(room.id, "livekit")
        Voice::ParticipantTracker.set_recording(
          room.id,
          egress_id: "EG_1",
          user_id: user.id,
          username: user.username,
          started_at: Time.now.to_f,
        )
      end

      it "clears the recording state and broadcasts the end" do
        messages =
          MessageBus.track_publish(Voice.room_channel(room.id)) { post_webhook(egress_event) }

        expect(response.status).to eq(200)
        expect(Voice::RecordingManager.status(room.id)).to be_nil
        recording_messages = messages.select { |message| message.data[:type] == "recording" }
        expect(recording_messages.size).to eq(1)
        expect(recording_messages.first.data[:recording]).to be_nil
      end

      it "handles a snake_case egress webhook" do
        post_webhook(egress_event(snake_case: true))

        expect(response.status).to eq(200)
        expect(Voice::RecordingManager.status(room.id)).to be_nil
      end

      it "ignores an egress that is not the active recording" do
        post_webhook(egress_event(egress_id: "EG_other"))

        expect(response.status).to eq(200)
        expect(Voice::RecordingManager.status(room.id)).to be_present
      end

      it "ignores events for rooms outside this site's namespace" do
        post_webhook(egress_event(room_name: "othersite-r#{room.id}"))

        expect(response.status).to eq(200)
        expect(Voice::RecordingManager.status(room.id)).to be_present
      end

      it "finalizes the recording row and PMs the requester the file location" do
        recording =
          Voice::Recording.create!(
            room: room,
            started_by: user,
            egress_id: "EG_1",
            filepath: "voice/test-abc123",
            started_at: 10.minutes.ago,
          )

        event = egress_event
        event["egressInfo"]["fileResults"] = [
          {
            "filename" => "voice/test-abc123.mp4",
            "location" => "https://cdn.example.com/voice/test-abc123.mp4",
            "duration" => (300 * 1_000_000_000).to_s,
            "size" => "1000",
          },
        ]
        post_webhook(event)

        expect(response.status).to eq(200)
        expect(recording.reload.status).to eq("completed")
        expect(recording.location).to eq("https://cdn.example.com/voice/test-abc123.mp4")

        pm_topic =
          Topic.private_messages_for_user(user).find_by(
            title: I18n.t("voice.recording_ready_pm.title", room_name: room.name),
          )
        expect(pm_topic.first_post.raw).to include(recording.location)
      end
    end

    it "returns 404 when the plugin is disabled" do
      SiteSetting.voice_enabled = false

      post_webhook

      expect(response.status).to eq(404)
    end
  end
end

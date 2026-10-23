# frozen_string_literal: true

require "rails_helper"

RSpec.describe Live::LivekitWebhooksController do
  fab!(:user)
  fab!(:room) { Fabricate(:live_room, public: true) }

  before do
    SiteSetting.live_enabled = true
    SiteSetting.live_allowed_groups =
      "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"
    SiteSetting.live_livekit_url = "wss://livekit.example.com"
    SiteSetting.live_livekit_api_key = "lk_api_key"
    SiteSetting.live_livekit_api_secret = "lk_api_secret"
    SiteSetting.live_livekit_room_policy = "all_rooms"
  end

  after do
    Live::ParticipantTracker.clear(room.id)
    Discourse.redis.del(Live::Livekit::LAST_WEBHOOK_KEY)
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
    room_name: Live::Livekit.room_name(room),
    identity: user.id.to_s,
    sid: "PA_test",
    metadata: nil,
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
        "metadata" => metadata,
      },
    }
  end

  def post_webhook(event = event_for, headers: nil)
    body = event.to_json
    post "/live/livekit/webhook", params: body, headers: headers || signed_headers(body)
  end

  describe "#create" do
    it "reconciles a dashboard agent without letting stale events restore a kicked bot" do
      SiteSetting.live_livekit_url = "wss://test.livekit.cloud"
      SiteSetting.live_livekit_agent_enabled = true
      Live::ParticipantTracker.pin_transport!(room.id, "livekit")
      Live::ParticipantTracker.add(room.id, user.id)
      dispatch = nil
      stub_request(
        :post,
        "https://test.livekit.cloud/twirp/livekit.AgentDispatchService/CreateDispatch",
      ).to_return do |request|
        dispatch =
          JSON.parse(request.body).merge(
            "id" => "AD_test",
            "state" => {
              "jobs" => [
                {
                  "dispatchId" => "AD_test",
                  "state" => {
                    "status" => "JS_RUNNING",
                    "participantIdentity" => "agent-test",
                  },
                },
              ],
            },
          )
        { status: 200, body: dispatch.to_json }
      end
      stub_request(
        :post,
        "https://test.livekit.cloud/twirp/livekit.AgentDispatchService/ListDispatch",
      ).to_return { { status: 200, body: { agentDispatches: [dispatch] }.to_json } }
      stub_request(
        :post,
        "https://test.livekit.cloud/twirp/livekit.RoomService/ListParticipants",
      ).to_return(
        status: 200,
        body: {
          participants: [{ identity: "agent-test", kind: "AGENT", sid: "PA_current" }],
        }.to_json,
      )
      stub_request(
        :post,
        "https://test.livekit.cloud/twirp/livekit.RoomService/UpdateParticipant",
      ).to_return(status: 200, body: "{}")
      stub_request(
        :post,
        "https://test.livekit.cloud/twirp/livekit.AgentDispatchService/DeleteDispatch",
      ).to_return(status: 200, body: "{}")
      Live::AgentDispatcher.dispatch!(room:, agent_name: "assistant")
      bot = Live::AgentBot.user

      post_webhook(event_for(event: "participant_joined", identity: "agent-test"))
      expect(response.status).to eq(200)
      expect(Live::ParticipantTracker.agent_user_ids(room.id)).to eq([bot.id])

      post_webhook(event_for(identity: "agent-test", sid: "PA_old"))
      expect(Live::ParticipantTracker.agent_user_ids(room.id)).to eq([bot.id])

      Live::AgentManager.evict!(room:, user_id: bot.id)
      post_webhook(event_for(event: "participant_joined", identity: "agent-test"))
      expect(Live::ParticipantTracker.agent_user_ids(room.id)).to be_empty
    end

    context "with an invalid delivery" do
      it "rejects a request with no Authorization token and records no delivery" do
        body = event_for.to_json

        post "/live/livekit/webhook",
             params: body,
             headers: {
               "CONTENT_TYPE" => "application/webhook+json",
             }

        expect(response.status).to eq(403)
        expect(Live::Livekit.last_webhook_at).to be_nil
      end

      it "rejects a token signed with the wrong secret" do
        body = event_for.to_json

        post "/live/livekit/webhook",
             params: body,
             headers: signed_headers(body, secret: "not-the-secret")

        expect(response.status).to eq(403)
      end

      it "rejects an expired token" do
        body = event_for.to_json

        post "/live/livekit/webhook", params: body, headers: signed_headers(body, exp: 1.minute.ago)

        expect(response.status).to eq(403)
      end

      it "rejects a token issued for a different API key" do
        body = event_for.to_json

        post "/live/livekit/webhook", params: body, headers: signed_headers(body, key: "other")

        expect(response.status).to eq(403)
      end

      it "rejects a body that does not match the signed hash" do
        signed_body = event_for.to_json
        tampered_body = event_for(identity: "999").to_json

        post "/live/livekit/webhook", params: tampered_body, headers: signed_headers(signed_body)

        expect(response.status).to eq(403)
        expect(Live::ParticipantTracker.pinned_transport(room.id)).to be_nil
      end

      it "rejects everything when LiveKit is unconfigured" do
        body = event_for.to_json
        headers = signed_headers(body)
        SiteSetting.live_livekit_api_secret = ""

        post "/live/livekit/webhook", params: body, headers: headers

        expect(response.status).to eq(403)
      end
    end

    it "records the delivery time of every verified webhook, including unhandled events" do
      post_webhook(event_for(event: "room_started"))

      expect(response.status).to eq(200)
      expect(Live::Livekit.last_webhook_at).to be_within(5.seconds).of(Time.now)
    end

    %w[participant_left participant_connection_aborted].each do |event_name|
      context "with a #{event_name} event" do
        it "expires the participant's presence, keeps their metadata, and broadcasts the change" do
          Live::ParticipantTracker.pin_transport!(room.id, "livekit")
          Live::ParticipantTracker.add(room.id, user.id)
          Live::ParticipantTracker.update_metadata(room.id, user.id, { role: "participant" })

          messages =
            MessageBus.track_publish(Live.room_channel(room.id)) do
              post_webhook(event_for(event: event_name))
            end

          expect(response.status).to eq(200)
          expect(Live::ParticipantTracker.user_ids(room.id)).not_to include(user.id)
          expect(Live::ParticipantTracker.get_metadata(room.id, user.id)[:role]).to eq(
            "participant",
          )
          expect(messages.map { |message| message.data[:type] }).to include("participants")
        end
      end
    end

    context "with a participant_left event" do
      it "leaves presence alone when it was refreshed after the event fired" do
        Live::ParticipantTracker.pin_transport!(room.id, "livekit")
        Live::ParticipantTracker.add(room.id, user.id)

        post_webhook(event_for(created_at: 2.minutes.ago))

        expect(response.status).to eq(200)
        expect(Live::ParticipantTracker.user_ids(room.id)).to include(user.id)
      end

      it "never creates presence for a participant who is not in the room" do
        Live::ParticipantTracker.pin_transport!(room.id, "livekit")

        post_webhook

        expect(response.status).to eq(200)
        expect(Live::ParticipantTracker.user_ids(room.id)).to be_empty
      end

      it "ignores rooms pinned to mesh" do
        Live::ParticipantTracker.pin_transport!(room.id, "mesh")
        Live::ParticipantTracker.add(room.id, user.id)

        post_webhook

        expect(response.status).to eq(200)
        expect(Live::ParticipantTracker.user_ids(room.id)).to include(user.id)
      end

      it "ignores rooms with no pinned transport" do
        Live::ParticipantTracker.add(room.id, user.id)

        post_webhook

        expect(response.status).to eq(200)
        expect(Live::ParticipantTracker.user_ids(room.id)).to include(user.id)
      end

      it "ignores events for rooms outside this site's namespace" do
        Live::ParticipantTracker.pin_transport!(room.id, "livekit")
        Live::ParticipantTracker.add(room.id, user.id)

        post_webhook(event_for(room_name: "othersite-r#{room.id}"))

        expect(response.status).to eq(200)
        expect(Live::ParticipantTracker.user_ids(room.id)).to include(user.id)
      end

      it "ignores a non-numeric participant identity" do
        Live::ParticipantTracker.pin_transport!(room.id, "livekit")
        Live::ParticipantTracker.add(room.id, user.id)

        post_webhook(event_for(identity: "recorder-bot"))

        expect(response.status).to eq(200)
        expect(Live::ParticipantTracker.user_ids(room.id)).to include(user.id)
      end

      it "leaves the session row open for CloseOrphanedSessions to close" do
        stub_request(
          :post,
          "https://livekit.example.com/twirp/livekit.RoomService/DeleteRoom",
        ).to_return(status: 200, body: "{}")
        sign_in(user)
        post "/live/rooms/#{room.id}/join.json"
        expect(response.status).to eq(200)
        session = Live::Session.find_by(user_id: user.id, room_id: room.id)

        post_webhook

        expect(response.status).to eq(200)
        expect(Live::ParticipantTracker.user_ids(room.id)).not_to include(user.id)
        expect(session.reload.left_at).to be_nil

        Jobs::Live::CloseOrphanedSessions.new.execute({})

        expect(session.reload.left_at).to be_present
      end
    end

    context "with a rejoined participant" do
      before do
        Live::ParticipantTracker.pin_transport!(room.id, "livekit")
        Live::ParticipantTracker.add(room.id, user.id)
      end

      it "ignores the superseded session's late departure" do
        post_webhook(event_for(event: "participant_joined", sid: "PA_new"))
        post_webhook(event_for(sid: "PA_old"))

        expect(response.status).to eq(200)
        expect(Live::ParticipantTracker.user_ids(room.id)).to include(user.id)
      end

      it "expires presence when the departing session is the recorded one" do
        post_webhook(event_for(event: "participant_joined", sid: "PA_new"))
        post_webhook(event_for(sid: "PA_new"))

        expect(response.status).to eq(200)
        expect(Live::ParticipantTracker.user_ids(room.id)).not_to include(user.id)
      end

      it "expires presence when no session was recorded for the user" do
        post_webhook(event_for(sid: "PA_old"))

        expect(response.status).to eq(200)
        expect(Live::ParticipantTracker.user_ids(room.id)).not_to include(user.id)
      end
    end

    context "with a room_finished event" do
      it "clears the transport pin of a livekit room without touching presence" do
        Live::ParticipantTracker.pin_transport!(room.id, "livekit")
        Live::ParticipantTracker.add(room.id, user.id)

        post_webhook(event_for(event: "room_finished"))

        expect(response.status).to eq(200)
        expect(Live::ParticipantTracker.pinned_transport(room.id)).to be_nil
        expect(Live::ParticipantTracker.user_ids(room.id)).to include(user.id)
      end

      it "keeps a mesh room's pin" do
        Live::ParticipantTracker.pin_transport!(room.id, "mesh")

        post_webhook(event_for(event: "room_finished"))

        expect(response.status).to eq(200)
        expect(Live::ParticipantTracker.pinned_transport(room.id)).to eq("mesh")
      end
    end

    context "with an egress_ended event" do
      def egress_event(
        egress_id: "EG_1",
        room_name: Live::Livekit.room_name(room),
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
        Live::ParticipantTracker.pin_transport!(room.id, "livekit")
        Live::ParticipantTracker.set_recording(
          room.id,
          egress_id: "EG_1",
          user_id: user.id,
          username: user.username,
          started_at: Time.now.to_f,
        )
      end

      it "clears the recording state and broadcasts the end" do
        messages =
          MessageBus.track_publish(Live.room_channel(room.id)) { post_webhook(egress_event) }

        expect(response.status).to eq(200)
        expect(Live::RecordingManager.status(room.id)).to be_nil
        recording_messages = messages.select { |message| message.data[:type] == "recording" }
        expect(recording_messages.size).to eq(1)
        expect(recording_messages.first.data[:recording]).to be_nil
      end

      it "handles a snake_case egress webhook" do
        post_webhook(egress_event(snake_case: true))

        expect(response.status).to eq(200)
        expect(Live::RecordingManager.status(room.id)).to be_nil
      end

      it "ignores an egress that is not the active recording" do
        post_webhook(egress_event(egress_id: "EG_other"))

        expect(response.status).to eq(200)
        expect(Live::RecordingManager.status(room.id)).to be_present
      end

      it "ignores events for rooms outside this site's namespace" do
        post_webhook(egress_event(room_name: "othersite-r#{room.id}"))

        expect(response.status).to eq(200)
        expect(Live::RecordingManager.status(room.id)).to be_present
      end

      it "finalizes the recording row and PMs the requester the file location" do
        recording =
          Live::Recording.create!(
            room: room,
            started_by: user,
            egress_id: "EG_1",
            filepath: "live/test-abc123",
            started_at: 10.minutes.ago,
          )

        event = egress_event
        event["egressInfo"]["fileResults"] = [
          {
            "filename" => "live/test-abc123.mp4",
            "location" => "https://cdn.example.com/live/test-abc123.mp4",
            "duration" => (300 * 1_000_000_000).to_s,
            "size" => "1000",
          },
        ]
        post_webhook(event)

        expect(response.status).to eq(200)
        expect(recording.reload.status).to eq("completed")
        expect(recording.location).to eq("https://cdn.example.com/live/test-abc123.mp4")

        pm_topic =
          Topic.private_messages_for_user(user).find_by(
            title: I18n.t("live.recording_ready_pm.title", room_name: room.name),
          )
        expect(pm_topic.first_post.raw).to include(recording.location)
      end
    end

    it "returns 404 when the plugin is disabled" do
      SiteSetting.live_enabled = false

      post_webhook

      expect(response.status).to eq(404)
    end
  end
end

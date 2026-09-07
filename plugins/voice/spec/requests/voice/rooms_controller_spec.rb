# frozen_string_literal: true
require "rails_helper"
require_relative "../../../db/migrate/20241107000000_create_voice_rooms"
require_relative "../../../db/migrate/20260612135211_add_video_enabled_to_voice_rooms"
require_relative "../../../db/migrate/20260630183841_add_chat_settings_to_voice_rooms"
require_relative "../../../db/migrate/20260813160047_create_voice_invites"

RSpec.describe Voice::RoomsController do
  before do
    ActiveRecord::Migration.suppress_messages do
      CreateVoiceRooms.new.change unless ActiveRecord::Base.connection.table_exists?(:voice_rooms)
      unless ActiveRecord::Base.connection.column_exists?(:voice_rooms, :video_enabled)
        AddVideoEnabledToVoiceRooms.new.change
      end
      unless ActiveRecord::Base.connection.column_exists?(:voice_rooms, :chat_channel_id)
        AddChatSettingsToVoiceRooms.new.change
      end
      unless ActiveRecord::Base.connection.table_exists?(:voice_invites)
        CreateVoiceInvites.new.change
      end
    end
    Voice::Room.reset_column_information
  end

  fab!(:staff, :admin)
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:other_participant) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:room) { Fabricate(:voice_room, creator: staff, public: true) }
  fab!(:room_owner) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:private_room_member) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:private_room) { Fabricate(:voice_room, creator: room_owner, public: false) }

  fab!(:private_room_membership) do
    private_room.room_memberships.create!(
      user: private_room_member,
      role: Voice::RoomMembership::ROLE_PARTICIPANT,
    )
  end

  before do
    SiteSetting.voice_enabled = true
    SiteSetting.voice_allowed_groups =
      "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"
    SiteSetting.voice_create_room_allowed_groups = "#{Group::AUTO_GROUPS[:trust_level_2]}"
  end

  # Presence plus the server-attested participant session that signal,
  # heartbeat, and state require. Returns the session id to send back.
  def establish_presence!(target_room, target_user)
    Voice::ParticipantTracker.add(target_room.id, target_user.id)
    Voice::ParticipantTracker.create_participant_session!(target_room.id, target_user.id)
  end

  describe "#index" do
    it "returns rooms visible to the user" do
      sign_in(user)

      get "/voice/rooms.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["rooms"]).to be_present
    end

    it "returns message-bus positions for gap-free subscriptions" do
      sign_in(user)

      get "/voice/rooms.json"

      expect(response.parsed_body["index_message_bus_last_id"]).to be_a(Integer)
      expect(response.parsed_body["rooms"].first["message_bus_last_id"]).to be_a(Integer)
    end

    it "returns preloaded participant and recording state" do
      sign_in(user)
      Voice::ParticipantTracker.add(room.id, other_participant.id)
      Voice::ParticipantTracker.update_metadata(room.id, other_participant.id, muted: true)
      Voice::ParticipantTracker.set_recording(
        room.id,
        egress_id: "EG_1",
        user_id: staff.id,
        username: staff.username,
        started_at: 123.0,
      )

      get "/voice/rooms.json"

      listed_room = response.parsed_body["rooms"].find { |candidate| candidate["id"] == room.id }
      expect(listed_room["active_participants"]).to contain_exactly(
        include("id" => other_participant.id, "muted" => true),
      )
      expect(listed_room["recording"]).to eq(
        "started_at" => 123.0,
        "started_by" => {
          "id" => staff.id,
          "username" => staff.username,
        },
      )
    ensure
      Voice::ParticipantTracker.clear(room.id)
    end

    it "does not add membership queries as the directory grows" do
      sign_in(user)
      get "/voice/rooms.json"

      initial_queries =
        track_sql_queries { get "/voice/rooms.json" }.grep(/voice_room_memberships/).size

      4.times { Fabricate(:voice_room, creator: Fabricate(:user), public: true) }
      expanded_queries =
        track_sql_queries { get "/voice/rooms.json" }.grep(/voice_room_memberships/).size

      expect(expanded_queries).to eq(initial_queries)
    end

    it "does not add chat channel queries as the directory grows" do
      SiteSetting.voice_chat_enabled = true
      SiteSetting.chat_enabled = true
      room.update!(chat_channel_id: Fabricate(:chat_channel, threading_enabled: true).id)
      sign_in(staff)

      initial_queries =
        track_sql_queries { get "/voice/rooms.json" }.grep(/FROM "chat_channels"/).size

      4.times do
        channel = Fabricate(:chat_channel, threading_enabled: true)
        Fabricate(:voice_room, creator: Fabricate(:user), public: true, chat_channel_id: channel.id)
      end
      expanded_queries =
        track_sql_queries { get "/voice/rooms.json" }.grep(/FROM "chat_channels"/).size

      expect(initial_queries).to eq(1)
      expect(expanded_queries).to eq(initial_queries)
    end

    it "hides non-public rooms from non-members who can create rooms" do
      sign_in(user)

      get "/voice/rooms.json"

      expect(response.status).to eq(200)
      room_ids = response.parsed_body["rooms"].map { |listed_room| listed_room["id"] }
      expect(room_ids).not_to include(private_room.id)
      expect(response.parsed_body["can_create_room"]).to eq(true)
    end

    it "includes non-public rooms for their members" do
      sign_in(private_room_member)

      get "/voice/rooms.json"

      room_ids = response.parsed_body["rooms"].map { |listed_room| listed_room["id"] }
      expect(room_ids).to include(room.id, private_room.id)
    end

    it "includes non-public rooms for site staff" do
      sign_in(staff)

      get "/voice/rooms.json"

      room_ids = response.parsed_body["rooms"].map { |listed_room| listed_room["id"] }
      expect(room_ids).to include(private_room.id)
    end

    it "never lists ephemeral rooms, even to their members or staff" do
      ephemeral = Fabricate(:voice_ephemeral_room, creator: staff, public: true)
      sign_in(staff)

      get "/voice/rooms.json"

      room_ids = response.parsed_body["rooms"].map { |listed_room| listed_room["id"] }
      expect(room_ids).not_to include(ephemeral.id)
    end

    context "when anonymous" do
      it "returns only public rooms when access is open to everyone" do
        get "/voice/rooms.json"

        expect(response.status).to eq(200)
        room_ids = response.parsed_body["rooms"].map { |r| r["id"] }
        expect(room_ids).to include(room.id)
        expect(room_ids).not_to include(private_room.id)
        expect(response.parsed_body["can_create_room"]).to eq(false)
      end

      it "returns no rooms when access is restricted to a group" do
        SiteSetting.voice_allowed_groups = "#{Group::AUTO_GROUPS[:trust_level_2]}"

        get "/voice/rooms.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["rooms"]).to be_empty
      end
    end
  end

  describe "#show" do
    it "serves an ephemeral room directly, even though it is never listed" do
      ephemeral = Fabricate(:voice_ephemeral_room, creator: staff, public: true)
      sign_in(user)

      get "/voice/rooms/#{ephemeral.id}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["room"]["ephemeral"]).to eq(true)
    end

    it "returns 403 for a non-member who can create rooms" do
      sign_in(user)

      get "/voice/rooms/#{private_room.id}.json"

      expect(response.status).to eq(403)
    end

    it "returns the room to a member" do
      sign_in(private_room_member)

      get "/voice/rooms/#{private_room.id}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["room"]["id"]).to eq(private_room.id)
    end

    it "returns the room to site staff who aren't members" do
      sign_in(staff)

      get "/voice/rooms/#{private_room.id}.json"

      expect(response.status).to eq(200)
    end

    it "returns 403 to anonymous visitors for non-public rooms" do
      get "/voice/rooms/#{private_room.id}.json"

      expect(response.status).to eq(403)
    end
  end

  describe "#create" do
    it "allows trusted user to create a room" do
      sign_in(user)

      post "/voice/rooms.json", params: { room: { name: "Game Night", public: true } }

      expect(response.status).to eq(200)
      expect(response.parsed_body["room"]["name"]).to eq("Game Night")
    end

    it "accepts an optional slug and generates one when it is blank" do
      sign_in(user)

      post "/voice/rooms.json",
           params: {
             room: {
               name: "Game Night",
               slug: "Friday Hangout",
               public: true,
             },
           }
      expect(response.status).to eq(200)
      expect(response.parsed_body["room"]["slug"]).to eq("friday-hangout")

      post "/voice/rooms.json", params: { room: { name: "Movie Night", slug: "", public: true } }
      expect(response.status).to eq(200)
      expect(response.parsed_body["room"]["slug"]).to eq("movie-night")
    end

    it "does not count ephemeral rooms against the per-user room limit" do
      SiteSetting.voice_max_rooms_per_user = 1
      Fabricate(:voice_ephemeral_room, creator: user)
      sign_in(user)

      post "/voice/rooms.json", params: { room: { name: "Game Night", public: true } }

      expect(response.status).to eq(200)
    end

    it "denies room creation to users outside the create-room groups" do
      low_trust_user = Fabricate(:user, trust_level: TrustLevel[0])
      sign_in(low_trust_user)

      post "/voice/rooms.json", params: { room: { name: "Game Night", public: true } }

      expect(response.status).to eq(403)
    end
  end

  describe "#join" do
    it "returns a participant session id and rotates it on rejoin" do
      sign_in(user)

      post "/voice/rooms/#{room.id}/join.json"
      first_session_id = response.parsed_body["participant_session_id"]

      expect(first_session_id).to be_present
      expect(
        Voice::ParticipantTracker.valid_participant_session?(room.id, user.id, first_session_id),
      ).to eq(true)

      post "/voice/rooms/#{room.id}/join.json"
      second_session_id = response.parsed_body["participant_session_id"]

      expect(second_session_id).to be_present
      expect(second_session_id).not_to eq(first_session_id)
      expect(
        Voice::ParticipantTracker.valid_participant_session?(room.id, user.id, first_session_id),
      ).to eq(false)
    end

    it "treats a repeated join carrying the live session as idempotent" do
      sign_in(user)

      post "/voice/rooms/#{room.id}/join.json"
      session_id = response.parsed_body["participant_session_id"]
      expect(Voice::Session.where(user: user, room: room).count).to eq(1)

      messages =
        MessageBus.track_publish(Voice.room_channel(room.id)) do
          post "/voice/rooms/#{room.id}/join.json", params: { participant_session_id: session_id }
        end

      expect(response.status).to eq(200)
      expect(response.parsed_body["participant_session_id"]).to eq(session_id)
      expect(
        Voice::ParticipantTracker.valid_participant_session?(room.id, user.id, session_id),
      ).to eq(true)
      expect(Voice::Session.where(user: user, room: room).count).to eq(1)
      expect(messages.select { |message| message.data[:type] == "participants" }).to be_empty
    end

    it "reuses the open analytics session and skips join side effects for a present user omitting the session id" do
      SiteSetting.voice_analytics_enabled = true
      sign_in(user)

      post "/voice/rooms/#{room.id}/join.json"
      first_session_id = response.parsed_body["participant_session_id"]
      analytics_id = Voice::Session.find_by(user: user, room: room).id

      messages =
        MessageBus.track_publish(Voice.room_channel(room.id)) do
          5.times { post "/voice/rooms/#{room.id}/join.json" }
        end

      expect(response.status).to eq(200)
      # The takeover still rotates the participant session so the newest tab
      # holds signaling authority...
      expect(response.parsed_body["participant_session_id"]).not_to eq(first_session_id)
      # ...but replayed joins are not an analytics-row or broadcast factory.
      sessions = Voice::Session.where(user: user, room: room)
      expect(sessions.count).to eq(1)
      expect(sessions.first.id).to eq(analytics_id)
      expect(sessions.first.left_at).to be_nil
      expect(messages.select { |message| message.data[:type] == "participants" }).to be_empty
    end

    it "mints a fresh session and analytics session on a genuine rejoin after leave" do
      sign_in(user)

      post "/voice/rooms/#{room.id}/join.json"
      first_session_id = response.parsed_body["participant_session_id"]

      delete "/voice/rooms/#{room.id}/leave.json",
             params: {
               participant_session_id: first_session_id,
             }

      post "/voice/rooms/#{room.id}/join.json", params: { participant_session_id: first_session_id }

      expect(response.status).to eq(200)
      expect(response.parsed_body["participant_session_id"]).not_to eq(first_session_id)
      expect(Voice::Session.where(user: user, room: room).count).to eq(2)
    end

    it "returns 422 when the room is at its own participant limit" do
      room.update!(max_participants: 2)
      establish_presence!(room, staff)
      establish_presence!(room, other_participant)
      sign_in(user)

      post "/voice/rooms/#{room.id}/join.json"

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to include(I18n.t("voice.errors.room_full"))
      expect(Voice::ParticipantTracker.user_ids(room.id)).not_to include(user.id)
    end

    it "returns 422 when the room is at the site-wide participant ceiling" do
      SiteSetting.voice_max_room_participants = 2
      establish_presence!(room, staff)
      establish_presence!(room, other_participant)
      sign_in(user)

      post "/voice/rooms/#{room.id}/join.json"

      expect(response.status).to eq(422)
    end

    it "lets an existing participant rejoin a full room" do
      room.update!(max_participants: 2)
      establish_presence!(room, staff)
      establish_presence!(room, user)
      sign_in(user)

      post "/voice/rooms/#{room.id}/join.json"

      expect(response.status).to eq(200)
      expect(Voice::ParticipantTracker.user_ids(room.id)).to include(user.id)
    end

    it "frees the slots of participants whose presence expired" do
      room.update!(max_participants: 2)
      establish_presence!(room, staff)
      establish_presence!(room, other_participant)
      key = "#{Voice::ParticipantTracker::KEY_NAMESPACE}:#{room.id}:participants"
      Discourse.redis.zadd(key, 1.hour.ago.to_f, staff.id)
      sign_in(user)

      post "/voice/rooms/#{room.id}/join.json"

      expect(response.status).to eq(200)
      expect(Voice::ParticipantTracker.user_ids(room.id)).to contain_exactly(
        other_participant.id,
        user.id,
      )
    end

    it "returns 403 when a non-member who can create rooms joins a private room" do
      sign_in(user)

      post "/voice/rooms/#{private_room.id}/join.json"

      expect(response.status).to eq(403)
      expect(Voice::ParticipantTracker.user_ids(private_room.id)).not_to include(user.id)
    end

    it "lets a member join a private room" do
      sign_in(private_room_member)

      post "/voice/rooms/#{private_room.id}/join.json"

      expect(response.status).to eq(200)
      expect(Voice::ParticipantTracker.user_ids(private_room.id)).to include(private_room_member.id)
    end

    it "lets site staff join a private room they aren't a member of" do
      sign_in(staff)

      post "/voice/rooms/#{private_room.id}/join.json"

      expect(response.status).to eq(200)
    end

    it "redeems a pending invite when joining with the inviter's username" do
      invite =
        Voice::Invite.create!(
          room_id: room.id,
          user_id: user.id,
          invited_by_id: other_participant.id,
          source: Voice::Invite::SOURCES[:notification],
        )
      sign_in(user)

      post "/voice/rooms/#{room.id}/join.json", params: { invited_by: other_participant.username }

      expect(response.status).to eq(200)
      expect(invite.reload.redeemed_at).to be_present
    end

    it "marks the room's unread invitation notifications read on join, leaving other rooms' alone" do
      Voice::RoomInviter.invite!(room: room, inviter: other_participant, users: [user])
      Voice::RoomInviter.invite!(room: private_room, inviter: room_owner, users: [user])
      invitation_notifications =
        user.notifications.where(notification_type: Notification.types[:voice_invitation])
      room_notification =
        invitation_notifications.find { |notification| notification.data_hash[:room_id] == room.id }
      other_room_notification =
        invitation_notifications.find do |notification|
          notification.data_hash[:room_id] == private_room.id
        end
      sign_in(user)

      post "/voice/rooms/#{room.id}/join.json"

      expect(response.status).to eq(200)
      expect(room_notification.reload.read).to eq(true)
      expect(other_room_notification.reload.read).to eq(false)
    end

    it "records a link invite when joining through a shared invite URL, only once" do
      sign_in(user)

      2.times do
        post "/voice/rooms/#{room.id}/join.json", params: { invited_by: other_participant.username }
        delete "/voice/rooms/#{room.id}/leave.json"
      end

      invites = Voice::Invite.where(room_id: room.id, user_id: user.id)
      expect(invites.count).to eq(1)
      expect(invites.first.source).to eq(Voice::Invite::SOURCES[:link])
      expect(invites.first.invited_by_id).to eq(other_participant.id)
      expect(invites.first.redeemed_at).to be_present
    end

    it "does not let users credit themselves through their own invite link" do
      sign_in(user)

      post "/voice/rooms/#{room.id}/join.json", params: { invited_by: user.username }

      expect(response.status).to eq(200)
      expect(Voice::Invite.count).to eq(0)
    end

    it "returns the ICE configuration with per-user TURN credentials" do
      SiteSetting.voice_stun_servers = ""
      SiteSetting.voice_turn_secret = "coturn-shared-secret"
      SiteSetting.voice_turn_secret_servers = "turn:turn.example.com:3478"
      sign_in(user)

      post "/voice/rooms/#{room.id}/join.json"

      expect(response.status).to eq(200)

      ice = response.parsed_body["ice"]
      turn_server = ice["servers"].first
      expiry, site, credential_user_id = turn_server["username"].split(":")

      expect(credential_user_id).to eq(user.id.to_s)
      expect(site).to eq(Discourse.current_hostname)
      expect(expiry.to_i).to be > Time.zone.now.to_i
      expect(turn_server["credential"]).to eq(
        Base64.strict_encode64(
          OpenSSL::HMAC.digest("SHA1", "coturn-shared-secret", turn_server["username"]),
        ),
      )
      expect(ice["transport_policy"]).to eq("all")
    end

    it "tracks users when they join a room" do
      sign_in(user)

      post "/voice/rooms/#{room.id}/join.json"

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["room"]["active_participants"].map { |p| p["id"] }).to include(user.id)
    end

    it "broadcasts participants to the allowed groups, anonymous subscribers included" do
      sign_in(user)
      Voice::ParticipantTracker.add(room.id, other_participant.id)

      messages =
        MessageBus.track_publish(Voice.room_channel(room.id)) do
          post "/voice/rooms/#{room.id}/join.json"
        end

      expect(response.status).to eq(200)

      participants_message = messages.find { |message| message.data[:type] == "participants" }
      expect(participants_message).to be_present
      expect(participants_message.group_ids).to include(
        Group::AUTO_GROUPS[:anonymous_users],
        Group::AUTO_GROUPS[:logged_in_users],
      )
    end

    context "with user status integration" do
      before do
        SiteSetting.enable_user_status = true
        SiteSetting.voice_auto_status_enabled = true
      end

      it "sets user status on join" do
        sign_in(user)

        post "/voice/rooms/#{room.id}/join.json"

        user.reload
        expect(user.user_status.emoji).to eq("studio_microphone")
        expect(user.user_status.description).to eq("In #{room.name}")
      end

      it "skips status when user already has one" do
        sign_in(user)
        user.set_status!("Busy", "no_entry")

        post "/voice/rooms/#{room.id}/join.json"

        user.reload
        expect(user.user_status.emoji).to eq("no_entry")
      end

      it "skips status when skip_status param is sent" do
        sign_in(user)

        post "/voice/rooms/#{room.id}/join.json", params: { skip_status: true }

        user.reload
        expect(user.user_status).to be_nil
      end
    end
  end

  describe "#leave" do
    before do
      SiteSetting.enable_user_status = true
      SiteSetting.voice_auto_status_enabled = true
    end

    it "clears Voice status on leave" do
      sign_in(user)
      Voice::ParticipantTracker.add(room.id, user.id)
      user.set_status!("In #{room.name}", "studio_microphone", 2.minutes.from_now)

      delete "/voice/rooms/#{room.id}/leave.json"

      expect(response.status).to eq(204)
      user.reload
      expect(user.user_status).to be_nil
    end

    it "preserves non-Voice status on leave" do
      sign_in(user)
      Voice::ParticipantTracker.add(room.id, user.id)
      user.set_status!("On vacation", "palm_tree")

      delete "/voice/rooms/#{room.id}/leave.json"

      expect(response.status).to eq(204)
      user.reload
      expect(user.user_status.emoji).to eq("palm_tree")
    end

    it "keeps the user out when a racing heartbeat lands after the leave" do
      sign_in(user)
      Voice::ParticipantTracker.add(room.id, user.id)

      delete "/voice/rooms/#{room.id}/leave.json"
      post "/voice/rooms/#{room.id}/heartbeat.json"

      expect(response.status).to eq(204)
      expect(Voice::ParticipantTracker.user_ids(room.id)).not_to include(user.id)
    end

    it "lets the user rejoin immediately after leaving" do
      sign_in(user)
      Voice::ParticipantTracker.add(room.id, user.id)

      delete "/voice/rooms/#{room.id}/leave.json"
      post "/voice/rooms/#{room.id}/join.json"

      expect(response.status).to eq(200)
      expect(Voice::ParticipantTracker.user_ids(room.id)).to include(user.id)
    end

    it "ignores a leave carrying a session that a newer join superseded" do
      sign_in(user)

      post "/voice/rooms/#{room.id}/join.json"
      stale_session_id = response.parsed_body["participant_session_id"]

      post "/voice/rooms/#{room.id}/join.json"
      current_session_id = response.parsed_body["participant_session_id"]

      delete "/voice/rooms/#{room.id}/leave.json",
             params: {
               participant_session_id: stale_session_id,
             }

      expect(response.status).to eq(204)
      expect(Voice::ParticipantTracker.user_ids(room.id)).to include(user.id)
      expect(
        Voice::ParticipantTracker.valid_participant_session?(room.id, user.id, current_session_id),
      ).to eq(true)
    end

    it "removes presence when the leave carries the current session" do
      sign_in(user)

      post "/voice/rooms/#{room.id}/join.json"
      session_id = response.parsed_body["participant_session_id"]

      delete "/voice/rooms/#{room.id}/leave.json", params: { participant_session_id: session_id }

      expect(response.status).to eq(204)
      expect(Voice::ParticipantTracker.user_ids(room.id)).not_to include(user.id)
      expect(Voice::ParticipantTracker.participant_session?(room.id, user.id)).to eq(false)
    end
  end

  describe "#heartbeat" do
    it "refreshes lapsed presence when the participant session is still valid" do
      sign_in(user)
      session_id = establish_presence!(room, user)

      # The heartbeat lapsed (laptop asleep) but the session TTL has not.
      key = "#{Voice::ParticipantTracker::KEY_NAMESPACE}:#{room.id}:participants"
      Discourse.redis.zadd(key, 1.hour.ago.to_f, user.id)

      post "/voice/rooms/#{room.id}/heartbeat.json", params: { participant_session_id: session_id }

      expect(response.status).to eq(204)
      expect(Voice::ParticipantTracker.user_ids(room.id)).to include(user.id)
    end

    it "rejects a heartbeat without a participant session and creates no presence" do
      sign_in(user)

      post "/voice/rooms/#{room.id}/heartbeat.json"

      expect(response.status).to eq(403)
      expect(Voice::ParticipantTracker.user_ids(room.id)).not_to include(user.id)
    end

    it "broadcasts the participant list when a stale participant has dropped out" do
      sign_in(user)
      session_id = establish_presence!(room, user)
      Voice::ParticipantTracker.add(room.id, other_participant.id)

      # other_participant left abruptly (refresh/close) and their heartbeat lapsed.
      key = "#{Voice::ParticipantTracker::KEY_NAMESPACE}:#{room.id}:participants"
      Discourse.redis.zadd(key, 1.hour.ago.to_f, other_participant.id)

      published = []
      allow(MessageBus).to receive(:publish) { |channel, data, _opts| published << data }

      post "/voice/rooms/#{room.id}/heartbeat.json", params: { participant_session_id: session_id }

      expect(response.status).to eq(204)
      participants_message = published.find { |data| data[:type] == "participants" }
      expect(participants_message).to be_present
      expect(participants_message[:participants].map { |p| p[:id] }).to contain_exactly(user.id)
    end

    it "does not broadcast when membership and state are unchanged" do
      sign_in(user)
      session_id = establish_presence!(room, user)
      # Prime the stored fingerprint so the next heartbeat sees no change.
      Voice::RoomBroadcaster.publish_participants_if_changed(room)

      published = []
      allow(MessageBus).to receive(:publish) { |channel, data, _opts| published << data }

      post "/voice/rooms/#{room.id}/heartbeat.json", params: { participant_session_id: session_id }

      expect(response.status).to eq(204)
      expect(published.find { |data| data[:type] == "participants" }).to be_nil
    end

    context "with user status integration" do
      before do
        SiteSetting.enable_user_status = true
        SiteSetting.voice_auto_status_enabled = true
        sign_in(user)
        @participant_session_id = establish_presence!(room, user)
        Voice::ParticipantTracker.update_metadata(room.id, user.id, { role: "participant" })
        Voice::UserStatusManager.set_voice_status(user, room)
      end

      it "keeps the status without an expiry across heartbeats" do
        post "/voice/rooms/#{room.id}/heartbeat.json",
             params: {
               participant_session_id: @participant_session_id,
             }

        user.reload
        expect(user.user_status.emoji).to eq("studio_microphone")
        expect(user.user_status.ends_at).to be_nil
      end

      it "does not republish an unchanged status on heartbeat" do
        messages =
          MessageBus.track_publish do
            post "/voice/rooms/#{room.id}/heartbeat.json",
                 params: {
                   participant_session_id: @participant_session_id,
                 }
          end

        expect(messages.select { |m| m.channel.include?("user-status") }).to be_empty
      end

      it "transitions to AFK status" do
        post "/voice/rooms/#{room.id}/heartbeat.json",
             params: {
               idle_state: "afk",
               participant_session_id: @participant_session_id,
             }

        user.reload
        expect(user.user_status.emoji).to eq("zzz")
        expect(user.user_status.description).to eq("AFK in #{room.name}")
      end

      it "transitions back from AFK to active status" do
        Voice::UserStatusManager.set_afk_status(user, room)

        post "/voice/rooms/#{room.id}/heartbeat.json",
             params: {
               idle_state: "active",
               participant_session_id: @participant_session_id,
             }

        user.reload
        expect(user.user_status.emoji).to eq("studio_microphone")
        expect(user.user_status.description).to eq("In #{room.name}")
      end

      it "skips status refresh when skip_status metadata is set" do
        Voice::ParticipantTracker.update_metadata(
          room.id,
          user.id,
          { role: "participant", skip_status: true },
        )
        user.clear_status!

        post "/voice/rooms/#{room.id}/heartbeat.json",
             params: {
               participant_session_id: @participant_session_id,
             }

        user.reload
        expect(user.user_status).to be_nil
      end
    end
  end

  describe "#kick" do
    before { Voice::ParticipantTracker.add(room.id, other_participant.id) }

    it "allows room manager to kick participants" do
      sign_in(staff)

      published = []
      allow(MessageBus).to receive(:publish) { |channel, data, opts|
        published << [channel, data, opts]
      }

      delete "/voice/rooms/#{room.id}/kick.json", params: { user_id: other_participant.id }

      expect(response.status).to eq(204)
      expect(Voice::ParticipantTracker.user_ids(room.id)).not_to include(other_participant.id)

      kick_message = published.find { |(_, data)| data[:type] == "kicked" }
      expect(kick_message).to be_present
      expect(kick_message[2][:user_ids]).to eq([other_participant.id])
    end

    it "prevents non-managers from kicking" do
      low_trust_user = Fabricate(:user, trust_level: TrustLevel[0])
      sign_in(low_trust_user)

      delete "/voice/rooms/#{room.id}/kick.json", params: { user_id: other_participant.id }

      expect(response.status).to eq(403)
    end

    it "prevents kicking oneself" do
      sign_in(staff)

      delete "/voice/rooms/#{room.id}/kick.json", params: { user_id: staff.id }

      expect(response.status).to eq(400)
    end

    it "clears kicked user's Voice status" do
      SiteSetting.enable_user_status = true
      SiteSetting.voice_auto_status_enabled = true
      sign_in(staff)
      other_participant.set_status!("In #{room.name}", "studio_microphone", 2.minutes.from_now)

      delete "/voice/rooms/#{room.id}/kick.json", params: { user_id: other_participant.id }

      expect(response.status).to eq(204)
      other_participant.reload
      expect(other_participant.user_status).to be_nil
    end

    it "keeps the kicked user out when their racing heartbeat lands after the kick" do
      sign_in(staff)
      delete "/voice/rooms/#{room.id}/kick.json", params: { user_id: other_participant.id }

      sign_in(other_participant)
      post "/voice/rooms/#{room.id}/heartbeat.json"

      expect(response.status).to eq(204)
      expect(Voice::ParticipantTracker.user_ids(room.id)).not_to include(other_participant.id)
    end

    it "prevents kicking the room creator" do
      sign_in(staff)
      other_room = Fabricate(:voice_room, creator: user, public: true)
      Voice::ParticipantTracker.add(other_room.id, user.id)

      delete "/voice/rooms/#{other_room.id}/kick.json", params: { user_id: user.id }

      expect(response.status).to eq(400)
    end
  end

  describe "#toggle_mute" do
    before { @participant_session_id = establish_presence!(room, user) }

    it "sets muted metadata and broadcasts participants" do
      sign_in(user)

      published = []
      allow(MessageBus).to receive(:publish) { |channel, data, opts|
        published << [channel, data, opts]
      }

      post "/voice/rooms/#{room.id}/toggle_mute.json",
           params: {
             muted: true,
             participant_session_id: @participant_session_id,
           }

      expect(response.status).to eq(204)

      metadata = Voice::ParticipantTracker.get_metadata(room.id, user.id)
      expect(metadata[:is_muted]).to eq(true)

      participants_message = published.find { |(_, data)| data[:type] == "participants" }
      expect(participants_message).to be_present
      muted_participant = participants_message[1][:participants].find { |p| p[:id] == user.id }
      expect(muted_participant[:is_muted]).to eq(true)
    end

    it "unmutes when muted is false" do
      sign_in(user)
      Voice::ParticipantTracker.update_metadata(room.id, user.id, { is_muted: true })

      post "/voice/rooms/#{room.id}/toggle_mute.json",
           params: {
             muted: false,
             participant_session_id: @participant_session_id,
           }

      expect(response.status).to eq(204)

      metadata = Voice::ParticipantTracker.get_metadata(room.id, user.id)
      expect(metadata[:is_muted]).to eq(false)
    end

    it "sets deafened metadata" do
      sign_in(user)

      post "/voice/rooms/#{room.id}/toggle_mute.json",
           params: {
             muted: true,
             deafened: true,
             participant_session_id: @participant_session_id,
           }

      expect(response.status).to eq(204)

      metadata = Voice::ParticipantTracker.get_metadata(room.id, user.id)
      expect(metadata[:is_muted]).to eq(true)
      expect(metadata[:is_deafened]).to eq(true)
    end

    it "requires authentication" do
      post "/voice/rooms/#{room.id}/toggle_mute.json", params: { muted: true }

      expect(response.status).to eq(403)
    end
  end

  describe "#state" do
    before do
      @participant_session_id = establish_presence!(room, user)
      sign_in(user)
    end

    it "rejects a state change without a participant session" do
      post "/voice/rooms/#{room.id}/state.json", params: { watching: true }

      expect(response.status).to eq(403)
      expect(Voice::ParticipantTracker.get_metadata(room.id, user.id)[:watching_video]).to be_nil
    end

    it "sets video metadata and broadcasts participants" do
      published = []
      allow(MessageBus).to receive(:publish) { |channel, data, opts|
        published << [channel, data, opts]
      }

      post "/voice/rooms/#{room.id}/state.json",
           params: {
             video: true,
             participant_session_id: @participant_session_id,
           }

      expect(response.status).to eq(204)

      metadata = Voice::ParticipantTracker.get_metadata(room.id, user.id)
      expect(metadata[:is_video_on]).to eq(true)

      participants_message = published.find { |(_, data)| data[:type] == "participants" }
      expect(participants_message).to be_present
      participant = participants_message[1][:participants].find { |entry| entry[:id] == user.id }
      expect(participant[:is_video_on]).to eq(true)
    end

    it "sets screen sharing and watching metadata" do
      post "/voice/rooms/#{room.id}/state.json",
           params: {
             screen: true,
             watching: true,
             participant_session_id: @participant_session_id,
           }

      expect(response.status).to eq(204)

      metadata = Voice::ParticipantTracker.get_metadata(room.id, user.id)
      expect(metadata[:is_screen_sharing]).to eq(true)
      expect(metadata[:watching_video]).to eq(true)
    end

    it "sets and clears the transcribing flag" do
      post "/voice/rooms/#{room.id}/state.json",
           params: {
             transcribing: true,
             participant_session_id: @participant_session_id,
           }

      expect(response.status).to eq(204)
      metadata = Voice::ParticipantTracker.get_metadata(room.id, user.id)
      expect(metadata[:is_transcribing]).to eq(true)

      post "/voice/rooms/#{room.id}/state.json",
           params: {
             transcribing: false,
             participant_session_id: @participant_session_id,
           }

      metadata = Voice::ParticipantTracker.get_metadata(room.id, user.id)
      expect(metadata[:is_transcribing]).to eq(false)
    end

    it "rejects video when no group is allowed to share a camera" do
      SiteSetting.voice_video_allowed_groups = ""

      post "/voice/rooms/#{room.id}/state.json",
           params: {
             video: true,
             participant_session_id: @participant_session_id,
           }

      expect(response.status).to eq(403)
    end

    it "rejects screen sharing when no group is allowed to share a screen" do
      SiteSetting.voice_screen_share_allowed_groups = ""

      post "/voice/rooms/#{room.id}/state.json",
           params: {
             screen: true,
             participant_session_id: @participant_session_id,
           }

      expect(response.status).to eq(403)
    end

    it "allows a camera when only screen sharing is disallowed" do
      SiteSetting.voice_screen_share_allowed_groups = ""

      post "/voice/rooms/#{room.id}/state.json",
           params: {
             video: true,
             participant_session_id: @participant_session_id,
           }

      expect(response.status).to eq(204)
      expect(Voice::ParticipantTracker.get_metadata(room.id, user.id)[:is_video_on]).to eq(true)
    end

    it "rejects video when the room has video disabled" do
      room.update!(video_enabled: false)

      post "/voice/rooms/#{room.id}/state.json",
           params: {
             video: true,
             participant_session_id: @participant_session_id,
           }

      expect(response.status).to eq(403)
    end

    it "rejects video from a stage listener" do
      room.update!(room_type: Voice::Room::ROOM_TYPE_STAGE)

      post "/voice/rooms/#{room.id}/state.json",
           params: {
             video: true,
             participant_session_id: @participant_session_id,
           }

      expect(response.status).to eq(403)
    end

    it "rejects screen share from a stage listener" do
      room.update!(room_type: Voice::Room::ROOM_TYPE_STAGE)

      post "/voice/rooms/#{room.id}/state.json",
           params: {
             screen: true,
             participant_session_id: @participant_session_id,
           }

      expect(response.status).to eq(403)
    end

    it "allows video from a stage speaker" do
      room.update!(room_type: Voice::Room::ROOM_TYPE_STAGE)
      room.room_memberships.create!(user: user, role: Voice::RoomMembership::ROLE_SPEAKER)

      post "/voice/rooms/#{room.id}/state.json",
           params: {
             video: true,
             participant_session_id: @participant_session_id,
           }

      expect(response.status).to eq(204)
      metadata = Voice::ParticipantTracker.get_metadata(room.id, user.id)
      expect(metadata[:is_video_on]).to eq(true)
    end

    it "allows screen share from a stage speaker" do
      room.update!(room_type: Voice::Room::ROOM_TYPE_STAGE)
      room.room_memberships.create!(user: user, role: Voice::RoomMembership::ROLE_SPEAKER)

      post "/voice/rooms/#{room.id}/state.json",
           params: {
             screen: true,
             participant_session_id: @participant_session_id,
           }

      expect(response.status).to eq(204)
    end

    it "rejects video when the publisher limit is reached" do
      SiteSetting.voice_video_max_publishers = 2

      publishers = Fabricate.times(2, :user)
      publishers.each do |publisher|
        Voice::ParticipantTracker.add(room.id, publisher.id)
        Voice::ParticipantTracker.update_metadata(room.id, publisher.id, { is_video_on: true })
      end

      post "/voice/rooms/#{room.id}/state.json",
           params: {
             video: true,
             participant_session_id: @participant_session_id,
           }

      expect(response.status).to eq(400)
    end

    it "allows an existing publisher to keep publishing at the limit" do
      SiteSetting.voice_video_max_publishers = 2

      publisher = Fabricate(:user)
      Voice::ParticipantTracker.add(room.id, publisher.id)
      Voice::ParticipantTracker.update_metadata(room.id, publisher.id, { is_video_on: true })
      Voice::ParticipantTracker.update_metadata(room.id, user.id, { is_video_on: true })

      post "/voice/rooms/#{room.id}/state.json",
           params: {
             video: true,
             participant_session_id: @participant_session_id,
           }

      expect(response.status).to eq(204)
    end

    it "allows turning video off even when video is disallowed" do
      Voice::ParticipantTracker.update_metadata(room.id, user.id, { is_video_on: true })
      room.update!(video_enabled: false)

      post "/voice/rooms/#{room.id}/state.json",
           params: {
             video: false,
             participant_session_id: @participant_session_id,
           }

      expect(response.status).to eq(204)
      metadata = Voice::ParticipantTracker.get_metadata(room.id, user.id)
      expect(metadata[:is_video_on]).to eq(false)
    end

    it "rejects a request with no supported state field" do
      post "/voice/rooms/#{room.id}/state.json",
           params: {
             participant_session_id: @participant_session_id,
             something_else: true,
           }

      expect(response.status).to eq(400)
    end

    it "publishes nothing when the request changes no state" do
      post "/voice/rooms/#{room.id}/state.json",
           params: {
             muted: true,
             participant_session_id: @participant_session_id,
           }

      messages =
        MessageBus.track_publish(Voice.room_channel(room.id)) do
          post "/voice/rooms/#{room.id}/state.json",
               params: {
                 muted: true,
                 participant_session_id: @participant_session_id,
               }
        end

      expect(response.status).to eq(204)
      expect(messages).to be_empty
    end

    it "still updates mute state through the toggle_mute alias" do
      post "/voice/rooms/#{room.id}/toggle_mute.json",
           params: {
             muted: true,
             participant_session_id: @participant_session_id,
           }

      expect(response.status).to eq(204)
      metadata = Voice::ParticipantTracker.get_metadata(room.id, user.id)
      expect(metadata[:is_muted]).to eq(true)
    end
  end

  describe "#update" do
    it "lets a room manager toggle video_enabled" do
      sign_in(staff)

      put "/voice/rooms/#{room.id}.json", params: { room: { video_enabled: false } }

      expect(response.status).to eq(200)
      expect(room.reload.video_enabled).to eq(false)
      expect(response.parsed_body["room"]["video_enabled"]).to eq(false)
    end

    it "returns 403 for a non-member who can create rooms" do
      sign_in(user)

      expect {
        put "/voice/rooms/#{private_room.id}.json", params: { room: { name: "Hijacked" } }
      }.not_to change { private_room.reload.name }

      expect(response.status).to eq(403)
    end

    it "returns 403 for a plain participant member" do
      sign_in(private_room_member)

      put "/voice/rooms/#{private_room.id}.json", params: { room: { name: "Hijacked" } }

      expect(response.status).to eq(403)
    end

    it "lets the creator update their room" do
      sign_in(room_owner)

      put "/voice/rooms/#{private_room.id}.json", params: { room: { name: "New name" } }

      expect(response.status).to eq(200)
      expect(private_room.reload.name).to eq("New name")
    end

    it "lets a room manager change the slug" do
      sign_in(room_owner)

      put "/voice/rooms/#{private_room.id}.json", params: { room: { slug: "New Hangout" } }

      expect(response.status).to eq(200)
      expect(private_room.reload.slug).to eq("new-hangout")
    end

    it "keeps a stage room's type when an update sends an unknown room_type" do
      private_room.update!(room_type: Voice::Room::ROOM_TYPE_STAGE)
      sign_in(room_owner)

      put "/voice/rooms/#{private_room.id}.json", params: { room: { room_type: "arena" } }

      expect(response.status).to eq(400)
      expect(private_room.reload.stage?).to eq(true)
    end

    it "stores max_quality_profile by name and serializes it back" do
      sign_in(room_owner)

      put "/voice/rooms/#{private_room.id}.json", params: { room: { max_quality_profile: "high" } }

      expect(response.status).to eq(200)
      expect(private_room.reload.max_quality_profile).to eq(Voice::Room::QUALITY_PROFILES["high"])
      expect(response.parsed_body["room"]["max_quality_profile"]).to eq("high")
    end

    it "clears the room-level quality cap when set to site_default" do
      private_room.update!(max_quality_profile: Voice::Room::QUALITY_PROFILES["standard"])
      sign_in(room_owner)

      put "/voice/rooms/#{private_room.id}.json",
          params: {
            room: {
              max_quality_profile: "site_default",
            },
          }

      expect(response.status).to eq(200)
      expect(private_room.reload.max_quality_profile).to be_nil
    end
  end

  describe "#destroy" do
    it "returns 403 for a non-member who can create rooms" do
      sign_in(user)

      delete "/voice/rooms/#{private_room.id}.json"

      expect(response.status).to eq(403)
      expect(Voice::Room.exists?(private_room.id)).to eq(true)
    end

    it "lets the creator destroy their room" do
      sign_in(room_owner)

      delete "/voice/rooms/#{private_room.id}.json"

      expect(response.status).to eq(200)
      expect(Voice::Room.exists?(private_room.id)).to eq(false)
    end

    it "broadcasts the destroy to the members the room had" do
      sign_in(room_owner)

      messages =
        MessageBus.track_publish(Voice.room_index_channel) do
          delete "/voice/rooms/#{private_room.id}.json"
        end

      expect(response.status).to eq(200)
      destroy_message = messages.find { |message| message.data[:type] == :destroyed }
      expect(destroy_message).to be_present
      expect(destroy_message.user_ids).to contain_exactly(room_owner.id, private_room_member.id)
    end
  end

  describe "#participants" do
    before { Voice::ParticipantTracker.add(private_room.id, private_room_member.id) }

    it "returns 403 for a non-member who can create rooms" do
      sign_in(user)

      get "/voice/rooms/#{private_room.id}/participants.json"

      expect(response.status).to eq(403)
    end

    it "returns the participant list to a member" do
      sign_in(private_room_member)

      get "/voice/rooms/#{private_room.id}/participants.json"

      expect(response.status).to eq(200)
      participant_ids = response.parsed_body["participants"].map { |p| p["id"] }
      expect(participant_ids).to include(private_room_member.id)
    end
  end

  describe "#heartbeat on a private room" do
    it "returns 403 for a non-member who can create rooms" do
      sign_in(user)

      post "/voice/rooms/#{private_room.id}/heartbeat.json"

      expect(response.status).to eq(403)
      expect(Voice::ParticipantTracker.user_ids(private_room.id)).not_to include(user.id)
    end
  end

  describe "#signal on a private room" do
    it "returns 403 for a non-member who can create rooms" do
      sign_in(user)

      post "/voice/rooms/#{private_room.id}/signal.json",
           params: {
             payload: {
               type: "offer",
               sdp: "v=0",
               recipient_id: private_room_member.id,
             },
           }

      expect(response.status).to eq(403)
    end
  end

  describe "#kick on a private room" do
    before { Voice::ParticipantTracker.add(private_room.id, private_room_member.id) }

    it "returns 403 for a non-member who can create rooms" do
      sign_in(user)

      delete "/voice/rooms/#{private_room.id}/kick.json",
             params: {
               user_id: private_room_member.id,
             }

      expect(response.status).to eq(403)
      expect(Voice::ParticipantTracker.user_ids(private_room.id)).to include(private_room_member.id)
    end
  end

  describe "#join with metadata" do
    it "includes is_muted and is_deafened in active_participants when metadata exists" do
      sign_in(user)
      Voice::ParticipantTracker.add(room.id, other_participant.id)
      Voice::ParticipantTracker.update_metadata(
        room.id,
        other_participant.id,
        { is_muted: true, is_deafened: true },
      )

      post "/voice/rooms/#{room.id}/join.json"

      expect(response.status).to eq(200)
      participants = response.parsed_body["room"]["active_participants"]
      participant = participants.find { |p| p["id"] == other_participant.id }
      expect(participant["is_muted"]).to eq(true)
      expect(participant["is_deafened"]).to eq(true)
    end
  end

  describe "#signal" do
    before do
      sign_in(user)
      @participant_session_id = establish_presence!(room, user)
      establish_presence!(room, staff)
      establish_presence!(room, other_participant)
    end

    it "rejects missing payloads" do
      post "/voice/rooms/#{room.id}/signal.json",
           params: {
             payload: {
             },
             participant_session_id: @participant_session_id,
           }

      expect(response.status).to eq(400)
    end

    it "relays ICE candidate payloads with the server-serialized sender" do
      candidate_payload = {
        candidate: "candidate:347230118 1 udp 41819902 203.0.113.1 54400 typ host",
        sdpMid: "0",
        sdpMLineIndex: 0,
        usernameFragment: "abc123",
      }

      messages =
        MessageBus.track_publish(Voice.room_channel(room.id)) do
          post "/voice/rooms/#{room.id}/signal.json",
               params: {
                 payload: {
                   type: "candidate",
                   candidate: candidate_payload,
                   recipient_id: staff.id,
                 },
                 participant_session_id: @participant_session_id,
               }
        end

      expect(response.status).to eq(204)
      expect(messages.size).to eq(1)

      message = messages.first
      expect(message.data[:type]).to eq("signal")
      expect(message.data[:room_id]).to eq(room.id)
      expect(message.data[:sender_id]).to eq(user.id)
      expect(message.data[:sender][:username]).to eq(user.username)
      expect(message.data[:events].size).to eq(1)
      expect(message.data[:events].first[:type]).to eq("candidate")
      expect(message.data[:events].first[:candidate][:candidate]).to eq(
        candidate_payload[:candidate],
      )
      expect(message.user_ids).to eq([staff.id])
    end

    it "accepts batched events payloads" do
      messages =
        MessageBus.track_publish(Voice.room_channel(room.id)) do
          post "/voice/rooms/#{room.id}/signal.json",
               params: {
                 payload: {
                   recipient_id: staff.id,
                   events: [
                     { type: "offer", sdp: "v=0" },
                     {
                       type: "candidate",
                       candidate: {
                         candidate: "candidate:1 1 udp 2122260223 10.0.0.1 8998 typ host",
                       },
                     },
                   ],
                 },
                 participant_session_id: @participant_session_id,
               }
        end

      expect(response.status).to eq(204)
      expect(messages.size).to eq(1)

      message = messages.first
      expect(message.data[:sender_id]).to eq(user.id)
      expect(message.user_ids).to eq([staff.id])

      events = message.data[:events]
      expect(events.map { |event| event[:type] }).to eq(%w[offer candidate])
      expect(events.first[:sdp]).to eq("v=0")
      expect(events.last[:candidate][:candidate]).to eq(
        "candidate:1 1 udp 2122260223 10.0.0.1 8998 typ host",
      )
    end

    it "relays multi-recipient batched messages" do
      messages =
        MessageBus.track_publish(Voice.room_channel(room.id)) do
          post "/voice/rooms/#{room.id}/signal.json",
               params: {
                 payload: {
                   messages: [
                     { recipient_id: staff.id, events: [{ type: "offer", sdp: "v=0" }] },
                     {
                       recipient_id: other_participant.id,
                       events: [
                         {
                           type: "candidate",
                           candidate: {
                             candidate: "candidate:1 1 udp 2122260223 10.0.0.1 8998 typ host",
                           },
                         },
                       ],
                     },
                   ],
                 },
                 participant_session_id: @participant_session_id,
               }
        end

      expect(response.status).to eq(204)
      expect(messages.size).to eq(2)
      expect(messages.map { |message| message.data[:sender_id] }).to all(eq(user.id))

      offer = messages.find { |message| message.data[:events].first[:type] == "offer" }
      candidate = messages.find { |message| message.data[:events].first[:type] == "candidate" }

      expect(offer.data[:events].first[:sdp]).to eq("v=0")
      expect(offer.user_ids).to eq([staff.id])
      expect(candidate.data[:events].first[:candidate][:candidate]).to eq(
        "candidate:1 1 udp 2122260223 10.0.0.1 8998 typ host",
      )
      expect(candidate.user_ids).to eq([other_participant.id])
    end
  end

  describe "#signal validation" do
    before do
      sign_in(user)
      @participant_session_id = establish_presence!(room, user)
      establish_presence!(room, staff)
      establish_presence!(room, other_participant)
    end

    def post_signal_payload(payload)
      MessageBus.track_publish(Voice.room_channel(room.id)) do
        post "/voice/rooms/#{room.id}/signal.json",
             params: {
               payload: payload,
               participant_session_id: @participant_session_id,
             },
             as: :json
      end
    end

    def candidate_event(seq = 1)
      {
        type: "candidate",
        candidate: {
          candidate: "candidate:#{seq} 1 udp 2122260223 10.0.0.1 8998 typ host",
        },
      }
    end

    it "rejects an unknown event type and publishes nothing" do
      messages = post_signal_payload({ recipient_id: staff.id, events: [{ type: "datachannel" }] })

      expect(response.status).to eq(400)
      expect(messages).to be_empty
    end

    it "rejects an offer missing its sdp" do
      messages = post_signal_payload({ recipient_id: staff.id, events: [{ type: "offer" }] })

      expect(response.status).to eq(400)
      expect(messages).to be_empty
    end

    it "rejects an event carrying fields outside its type's shape" do
      messages =
        post_signal_payload(
          {
            recipient_id: staff.id,
            events: [{ type: "offer", sdp: "v=0", metadata: { room: "other" } }],
          },
        )

      expect(response.status).to eq(400)
      expect(messages).to be_empty
    end

    it "rejects a candidate whose body has unexpected keys" do
      messages =
        post_signal_payload(
          {
            recipient_id: staff.id,
            events: [{ type: "candidate", candidate: { candidate: "a", extra: "b" } }],
          },
        )

      expect(response.status).to eq(400)
      expect(messages).to be_empty
    end

    it "rejects an oversized sdp" do
      oversized = "a" * (Voice::SignalValidator::MAX_SDP_BYTES + 1)
      messages =
        post_signal_payload({ recipient_id: staff.id, events: [{ type: "offer", sdp: oversized }] })

      expect(response.status).to eq(400)
      expect(messages).to be_empty
    end

    it "rejects an oversized candidate" do
      oversized = "a" * (Voice::SignalValidator::MAX_CANDIDATE_BYTES + 1)
      messages =
        post_signal_payload(
          {
            recipient_id: staff.id,
            events: [{ type: "candidate", candidate: { candidate: oversized } }],
          },
        )

      expect(response.status).to eq(400)
      expect(messages).to be_empty
    end

    it "rejects a batch with more events than one recipient may receive" do
      events =
        (Voice::SignalValidator::MAX_EVENTS_PER_RECIPIENT + 1).times.map do |seq|
          candidate_event(seq)
        end
      messages = post_signal_payload({ recipient_id: staff.id, events: events })

      expect(response.status).to eq(400)
      expect(messages).to be_empty
    end

    it "rejects a batch with more recipients than the room can hold" do
      room.update!(max_participants: 2)

      messages =
        post_signal_payload(
          {
            messages: [
              { recipient_id: staff.id, events: [candidate_event] },
              { recipient_id: other_participant.id, events: [candidate_event] },
            ],
          },
        )

      expect(response.status).to eq(400)
      expect(messages).to be_empty
    end

    it "rejects a malformed batch wholesale even when other events are valid" do
      messages =
        post_signal_payload(
          {
            messages: [
              { recipient_id: staff.id, events: [{ type: "offer", sdp: "v=0" }] },
              { recipient_id: other_participant.id, events: [{ type: "evil" }] },
            ],
          },
        )

      expect(response.status).to eq(400)
      expect(messages).to be_empty
    end

    it "preserves event order within a recipient's batch" do
      messages =
        post_signal_payload(
          {
            recipient_id: staff.id,
            events: [{ type: "offer", sdp: "v=0" }, candidate_event(1), candidate_event(2)],
          },
        )

      expect(response.status).to eq(204)
      expect(messages.size).to eq(1)

      events = messages.first.data[:events]
      expect(events.map { |event| event[:type] }).to eq(%w[offer candidate candidate])
      expect(events.last[:candidate][:candidate]).to include("candidate:2")
    end

    it "publishes one envelope per recipient, not per event" do
      messages =
        post_signal_payload(
          {
            messages: [
              {
                recipient_id: staff.id,
                events: [{ type: "offer", sdp: "v=0" }, candidate_event(1)],
              },
              {
                recipient_id: other_participant.id,
                events: [{ type: "offer", sdp: "v=0" }, candidate_event(2)],
              },
            ],
          },
        )

      expect(response.status).to eq(204)
      expect(messages.size).to eq(2)
      expect(messages.map(&:user_ids)).to contain_exactly([staff.id], [other_participant.id])
      expect(messages.map { |message| message.data[:events].size }).to eq([2, 2])
    end
  end

  describe "#signal rate limits" do
    before do
      RateLimiter.enable
      sign_in(user)
      @participant_session_id = establish_presence!(room, user)
    end

    def candidate_event(seq = 1)
      {
        type: "candidate",
        candidate: {
          candidate: "candidate:#{seq} 1 udp 2122260223 10.0.0.1 8998 typ host",
        },
      }
    end

    # Recipients only need a live participant session for the relay to
    # deliver; real User records are not required.
    def recipient_sessions!(count)
      (1..count).map do |i|
        fake_id = 100_000 + i
        Voice::ParticipantTracker.create_participant_session!(room.id, fake_id)
        fake_id
      end
    end

    def post_burst(recipient_ids, events_per_recipient)
      MessageBus.track_publish(Voice.room_channel(room.id)) do
        post "/voice/rooms/#{room.id}/signal.json",
             params: {
               payload: {
                 messages:
                   recipient_ids.map do |recipient_id|
                     { recipient_id: recipient_id, events: events_per_recipient }
                   end,
               },
               participant_session_id: @participant_session_id,
             },
             as: :json
      end
    end

    it "accepts a full 50-person room trickle ICE burst without 429" do
      recipient_ids = recipient_sessions!(49)

      # The representative burst: one offer plus three 5-candidate batches to
      # every peer in the room, followed by a straggler candidate round.
      connect_events = [{ type: "offer", sdp: "v=0" }] + 15.times.map { |seq| candidate_event(seq) }
      messages = post_burst(recipient_ids, connect_events)

      expect(response.status).to eq(204)
      expect(messages.size).to eq(49)

      post_burst(recipient_ids, 5.times.map { |seq| candidate_event(seq) })
      expect(response.status).to eq(204)
    end

    it "rejects sustained signaling before any MessageBus work happens" do
      recipient_ids = recipient_sessions!(49)
      max_events =
        Voice::SignalValidator::MAX_EVENTS_PER_RECIPIENT.times.map { |seq| candidate_event(seq) }

      4.times do
        post_burst(recipient_ids, max_events)
        expect(response.status).to eq(204)
      end

      messages = post_burst(recipient_ids, max_events)

      expect(response.status).to eq(429)
      expect(messages).to be_empty
    end

    it "limits a room's aggregate signaling across users" do
      stub_const(Voice::RoomsController, :SIGNAL_EVENTS_PER_ROOM_PER_MINUTE, 40) do
        staff_session_id = establish_presence!(room, staff)
        recipient_sessions!(1)

        post "/voice/rooms/#{room.id}/signal.json",
             params: {
               payload: {
                 recipient_id: 100_001,
                 events: 25.times.map { |seq| candidate_event(seq) },
               },
               participant_session_id: @participant_session_id,
             },
             as: :json
        expect(response.status).to eq(204)

        sign_in(staff)
        messages =
          MessageBus.track_publish(Voice.room_channel(room.id)) do
            post "/voice/rooms/#{room.id}/signal.json",
                 params: {
                   payload: {
                     recipient_id: 100_001,
                     events: 25.times.map { |seq| candidate_event(seq) },
                   },
                   participant_session_id: staff_session_id,
                 },
                 as: :json
          end

        expect(response.status).to eq(429)
        expect(messages).to be_empty
      end
    end

    it "rate limits repeated invalid-session attempts" do
      sign_in(other_participant)

      30.times do
        post "/voice/rooms/#{room.id}/signal.json",
             params: {
               payload: {
                 recipient_id: user.id,
                 events: [candidate_event],
               },
             },
             as: :json
        expect(response.status).to eq(403)
      end

      post "/voice/rooms/#{room.id}/signal.json",
           params: {
             payload: {
               recipient_id: user.id,
               events: [candidate_event],
             },
           },
           as: :json

      expect(response.status).to eq(429)
    end
  end

  describe "#signal participant session enforcement" do
    def post_signal(sender_room, session_id, recipient:)
      post "/voice/rooms/#{sender_room.id}/signal.json",
           params: {
             payload: {
               type: "offer",
               sdp: "v=0",
               recipient_id: recipient.id,
             },
             participant_session_id: session_id,
           }
    end

    it "relays a valid-session offer even when the sender's roster broadcast is still in flight" do
      # The recipient is present; the sender joined but no participants
      # broadcast has been observed yet — the session alone must authorize the
      # early offer.
      sign_in(user)
      establish_presence!(room, other_participant)
      post "/voice/rooms/#{room.id}/join.json"
      session_id = response.parsed_body["participant_session_id"]

      messages =
        MessageBus.track_publish(Voice.room_channel(room.id)) do
          post_signal(room, session_id, recipient: other_participant)
        end

      expect(response.status).to eq(204)
      expect(messages.size).to eq(1)
      expect(messages.first.user_ids).to eq([other_participant.id])
    end

    it "rejects a signal from a room-eligible user without a participant session" do
      sign_in(user)
      establish_presence!(room, other_participant)

      messages =
        MessageBus.track_publish(Voice.room_channel(room.id)) do
          post_signal(room, nil, recipient: other_participant)
        end

      expect(response.status).to eq(403)
      expect(messages).to be_empty
    end

    it "rejects a pre-leave session after the user rejoined" do
      sign_in(user)
      establish_presence!(room, other_participant)

      post "/voice/rooms/#{room.id}/join.json"
      stale_session_id = response.parsed_body["participant_session_id"]

      delete "/voice/rooms/#{room.id}/leave.json"
      post "/voice/rooms/#{room.id}/join.json"

      messages =
        MessageBus.track_publish(Voice.room_channel(room.id)) do
          post_signal(room, stale_session_id, recipient: other_participant)
        end

      expect(response.status).to eq(403)
      expect(messages).to be_empty
    end

    it "revokes signaling authority when the user is kicked" do
      sign_in(user)
      establish_presence!(room, other_participant)
      post "/voice/rooms/#{room.id}/join.json"
      session_id = response.parsed_body["participant_session_id"]

      sign_in(staff)
      delete "/voice/rooms/#{room.id}/kick.json", params: { user_id: user.id }

      sign_in(user)
      messages =
        MessageBus.track_publish(Voice.room_channel(room.id)) do
          post_signal(room, session_id, recipient: other_participant)
        end

      expect(response.status).to eq(403)
      expect(messages).to be_empty
    end

    it "discards messages to recipients without a live session and delivers the rest" do
      sign_in(user)
      session_id = establish_presence!(room, user)
      establish_presence!(room, staff)

      messages =
        MessageBus.track_publish(Voice.room_channel(room.id)) do
          post "/voice/rooms/#{room.id}/signal.json",
               params: {
                 payload: {
                   messages: [
                     { recipient_id: staff.id, events: [{ type: "offer", sdp: "v=0" }] },
                     {
                       recipient_id: other_participant.id,
                       events: [{ type: "offer", sdp: "v=0" }],
                     },
                   ],
                 },
                 participant_session_id: session_id,
               }
        end

      expect(response.status).to eq(204)
      expect(messages.size).to eq(1)
      expect(messages.first.user_ids).to eq([staff.id])
    end

    it "discards a queued offer to a recipient who left the room" do
      sign_in(other_participant)
      session_id = establish_presence!(room, other_participant)
      establish_presence!(room, user)

      sign_in(user)
      delete "/voice/rooms/#{room.id}/leave.json"

      sign_in(other_participant)
      messages =
        MessageBus.track_publish(Voice.room_channel(room.id)) do
          post_signal(room, session_id, recipient: user)
        end

      expect(response.status).to eq(204)
      expect(messages).to be_empty
    end
  end

  describe "chat" do
    fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }

    before do
      SiteSetting.chat_enabled = true
      SiteSetting.chat_allowed_groups =
        "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"
      room.update!(chat_channel_id: channel.id)
    end

    after do
      Voice::ChatSession.clear(room.id)
      Voice::ParticipantTracker.clear(room.id)
    end

    def join_room!(joining_user)
      Voice::ParticipantTracker.add(room.id, joining_user.id)
    end

    describe "chat fields in the serialized room" do
      # Below the create-rooms group threshold, so not a manager of anything.
      fab!(:viewer) { Fabricate(:user, trust_level: TrustLevel[1]) }

      it "hides all chat fields from a signed-in non-participant" do
        sign_in(viewer)

        get "/voice/rooms/#{room.id}.json"

        room_json = response.parsed_body["room"]
        expect(room_json.keys).not_to include(
          "chat_available",
          "chat_channel_id",
          "chat_idle_minutes",
        )
      end

      it "hides all chat fields from the anonymously-scoped directory broadcast" do
        json = Voice::RoomSerializer.new(room, scope: Guardian.new(nil), root: false).as_json

        expect(json.keys).not_to include(:chat_available, :chat_channel_id, :chat_idle_minutes)
      end

      it "exposes availability — but not the settings — to a present participant" do
        sign_in(viewer)
        join_room!(viewer)

        get "/voice/rooms/#{room.id}.json"

        room_json = response.parsed_body["room"]
        expect(room_json["chat_available"]).to eq(true)
        expect(room_json.keys).not_to include("chat_channel_id", "chat_idle_minutes")
      end

      it "exposes the chat settings to a manager" do
        sign_in(staff)

        get "/voice/rooms/#{room.id}.json"

        room_json = response.parsed_body["room"]
        expect(room_json["chat_available"]).to eq(true)
        expect(room_json["chat_channel_id"]).to eq(channel.id)
        expect(room_json["chat_idle_minutes"]).to eq(15)
      end
    end

    describe "#chat_session" do
      it "returns the channel and an empty session before any chat" do
        sign_in(user)
        join_room!(user)

        get "/voice/rooms/#{room.id}/chat_session.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["channel_id"]).to eq(channel.id)
        expect(response.parsed_body["thread_id"]).to be_nil
      end

      it "returns 403 when chat is disabled site-wide" do
        SiteSetting.chat_enabled = false
        sign_in(user)
        join_room!(user)

        get "/voice/rooms/#{room.id}/chat_session.json"

        expect(response.status).to eq(403)
      end

      it "returns 403 when the room has no linked channel" do
        room.update!(chat_channel_id: nil)
        sign_in(user)
        join_room!(user)

        get "/voice/rooms/#{room.id}/chat_session.json"

        expect(response.status).to eq(403)
      end

      it "returns 403 when signed in but not present in the voice room" do
        sign_in(user)

        get "/voice/rooms/#{room.id}/chat_session.json"

        expect(response.status).to eq(403)
      end

      it "requires authentication" do
        get "/voice/rooms/#{room.id}/chat_session.json"

        expect(response.status).to eq(403)
      end
    end

    describe "#ensure_chat_session" do
      it "requires authentication" do
        post "/voice/rooms/#{room.id}/chat_session.json"

        expect(response.status).to eq(403)
      end

      it "returns 403 with the room's own message when signed in but not present" do
        sign_in(user)

        post "/voice/rooms/#{room.id}/chat_session.json"

        expect(response.status).to eq(403)
        expect(response.parsed_body["errors"]).to include(
          I18n.t("voice.errors.chat_requires_presence"),
        )
      end

      it "follows the caller on the channel without creating a thread" do
        sign_in(user)
        join_room!(user)

        post "/voice/rooms/#{room.id}/chat_session.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["channel_id"]).to eq(channel.id)
        expect(response.parsed_body["thread_id"]).to be_nil
        expect(Chat::Thread.where(channel_id: channel.id).count).to eq(0)

        # Followed, so chat's own message endpoints accept the user's posts.
        membership = channel.membership_for(user)
        expect(membership).to be_present
        expect(membership.following).to eq(true)
      end
    end

    describe "#chat_message" do
      it "requires authentication" do
        post "/voice/rooms/#{room.id}/chat_message.json", params: { message: "hi" }

        expect(response.status).to eq(403)
      end

      it "returns 403 with the room's own message when signed in but not present" do
        sign_in(user)

        post "/voice/rooms/#{room.id}/chat_message.json", params: { message: "hi" }

        expect(response.status).to eq(403)
        expect(response.parsed_body["errors"]).to include(
          I18n.t("voice.errors.chat_requires_presence"),
        )
      end

      it "opens a thread rooted on the message and exposes it via GET" do
        sign_in(user)
        join_room!(user)

        post "/voice/rooms/#{room.id}/chat_message.json", params: { message: "hello everyone" }

        expect(response.status).to eq(200)
        thread_id = response.parsed_body["thread_id"]
        expect(thread_id).to be_present

        thread = Chat::Thread.find(thread_id)
        expect(thread.channel_id).to eq(channel.id)
        expect(thread.original_message.message).to eq("In ##{room.slug}::room - hello everyone")
        expect(thread.original_message.user_id).to eq(user.id)

        get "/voice/rooms/#{room.id}/chat_session.json"
        expect(response.parsed_body["thread_id"]).to eq(thread_id)
      end

      it "delivers a racing message to the live thread instead of a new one" do
        sign_in(user)
        join_room!(user)
        post "/voice/rooms/#{room.id}/chat_message.json", params: { message: "first" }
        thread_id = response.parsed_body["thread_id"]

        sign_in(other_participant)
        join_room!(other_participant)
        post "/voice/rooms/#{room.id}/chat_message.json", params: { message: "second" }

        expect(response.parsed_body["thread_id"]).to eq(thread_id)
        expect(Chat::Thread.find(thread_id).replies.last.message).to eq("second")
      end

      it "does not bypass chat's per-user flood limit" do
        RateLimiter.enable
        SiteSetting.chat_allowed_messages_for_other_trust_levels = 1
        sign_in(user)
        join_room!(user)

        post "/voice/rooms/#{room.id}/chat_message.json", params: { message: "one" }
        expect(response.status).to eq(200)

        # A second message within the window would be free if this endpoint
        # skipped chat's limiter; it must be capped like normal chat.
        post "/voice/rooms/#{room.id}/chat_message.json", params: { message: "two" }
        expect(response.status).to eq(429)
      end

      it "surfaces the chat plugin's rejection reason as a 422, not a generic 403" do
        channel.update!(threading_enabled: false)
        sign_in(user)
        join_room!(user)

        post "/voice/rooms/#{room.id}/chat_message.json", params: { message: "hello" }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"].join).to match(/threading/i)
      end
    end
  end
end

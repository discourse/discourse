# frozen_string_literal: true

require "rails_helper"

RSpec.describe Live::StageRoles do
  fab!(:admin)
  fab!(:owner, :user)
  fab!(:listener, :user)
  fab!(:permanent_speaker, :user)
  fab!(:private_member, :user)
  fab!(:room) do
    Fabricate(:live_room, creator: owner, public: true, room_type: Live::Room::ROOM_TYPE_STAGE)
  end
  fab!(:private_room) do
    Fabricate(:live_room, creator: owner, public: false, room_type: Live::Room::ROOM_TYPE_STAGE)
  end

  before do
    SiteSetting.live_enabled = true
    SiteSetting.live_allowed_groups = "#{Group::AUTO_GROUPS[:logged_in_users]}"
  end

  after do
    Live::ParticipantTracker.clear(room.id)
    Live::ParticipantTracker.clear(private_room.id)
  end

  describe ".effective_role" do
    it "treats a site admin without an explicit membership as a moderator in stage rooms" do
      expect(described_class.effective_role(room, admin)).to eq("moderator")
    end

    it "returns participant for a regular user without a membership" do
      expect(described_class.effective_role(room, listener)).to eq("participant")
    end

    it "returns speaker for a user with a speaker membership" do
      room.room_memberships.create!(
        user: permanent_speaker,
        role: Live::RoomMembership::ROLE_SPEAKER,
      )
      expect(described_class.effective_role(room, permanent_speaker)).to eq("speaker")
    end
  end

  describe "session-only speakers" do
    def grant(target_room, user)
      described_class.grant_session_speaker!(target_room, user)
    end

    it "grants the speaker role without creating a membership" do
      grant(room, listener)

      expect(room.room_memberships.where(user: listener)).to be_empty
      expect(described_class.effective_role(room, listener)).to eq("speaker")
      expect(listener.guardian.can_speak_in_live_room?(room)).to eq(true)
    end

    it "ends every grant when the session speakers are cleared" do
      grant(room, listener)

      described_class.clear_session_speakers!(room)

      expect(described_class.effective_role(room, listener)).to eq("participant")
      expect(listener.guardian.can_speak_in_live_room?(room)).to eq(false)
    end

    it "leaves a private room member's membership untouched" do
      membership =
        private_room.room_memberships.create!(
          user: private_member,
          role: Live::RoomMembership::ROLE_PARTICIPANT,
        )

      grant(private_room, private_member)

      expect(membership.reload).to be_participant
      expect(described_class.effective_role(private_room, private_member)).to eq("speaker")

      described_class.clear_session_speakers!(private_room)

      expect(membership.reload).to be_participant
      expect(private_member.guardian.can_join_live_room?(private_room)).to eq(true)
      expect(private_member.guardian.can_speak_in_live_room?(private_room)).to eq(false)
    end

    it "does not record a grant for someone who can already speak" do
      perm =
        room.room_memberships.create!(
          user: permanent_speaker,
          role: Live::RoomMembership::ROLE_SPEAKER,
        )

      grant(room, permanent_speaker)

      expect(Live::ParticipantTracker.session_speaker?(room.id, permanent_speaker.id)).to eq(false)

      described_class.clear_session_speakers!(room)
      expect(perm.reload).to be_speaker
    end

    it "does not carry a grant over to an open room" do
      grant(room, listener)
      room.update!(room_type: Live::Room::ROOM_TYPE_OPEN)

      expect(described_class.effective_role(room, listener)).to eq("participant")
    end

    it "demotes a session speaker without creating a membership" do
      grant(room, listener)

      described_class.assign_role!(room, listener, role: Live::RoomMembership::ROLE_PARTICIPANT)

      expect(room.room_memberships.where(user: listener)).to be_empty
      expect(listener.guardian.can_speak_in_live_room?(room)).to eq(false)
    end

    it "replaces a grant with a permanent role" do
      grant(room, listener)

      described_class.assign_role!(room, listener, role: Live::RoomMembership::ROLE_SPEAKER)

      expect(room.room_memberships.find_by(user: listener)).to be_speaker
      expect(Live::ParticipantTracker.session_speaker?(room.id, listener.id)).to eq(false)
    end
  end

  describe "demotion media cleanup" do
    it "immediately resets muted, video, and screen share metadata when demoting a present speaker" do
      membership =
        room.room_memberships.create!(user: listener, role: Live::RoomMembership::ROLE_SPEAKER)
      Live::ParticipantTracker.add(room.id, listener.id)
      Live::ParticipantTracker.update_metadata(
        room.id,
        listener.id,
        role: "speaker",
        is_muted: false,
        is_video_on: true,
        is_screen_sharing: true,
      )

      described_class.update_membership!(
        room,
        membership,
        role: Live::RoomMembership::ROLE_PARTICIPANT,
      )

      metadata = Live::ParticipantTracker.get_metadata(room.id, listener.id)
      expect(metadata[:role]).to eq("participant")
      expect(metadata[:is_muted]).to eq(true)
      expect(metadata[:is_video_on]).to eq(false)
      expect(metadata[:is_screen_sharing]).to eq(false)
    end

    it "keeps the reported mute state when a role is granted in an open room" do
      room.update!(room_type: Live::Room::ROOM_TYPE_OPEN)
      Live::ParticipantTracker.add(room.id, listener.id)
      Live::ParticipantTracker.update_metadata(
        room.id,
        listener.id,
        role: "participant",
        is_muted: true,
      )

      described_class.assign_role!(room, listener, role: Live::RoomMembership::ROLE_SPEAKER)

      metadata = Live::ParticipantTracker.get_metadata(room.id, listener.id)
      expect(metadata[:role]).to eq("speaker")
      expect(metadata[:is_muted]).to eq(true)
    end
  end

  describe ".step_down!" do
    it "reverts a session-only speaker and resets their media state" do
      described_class.grant_session_speaker!(room, listener)
      Live::ParticipantTracker.add(room.id, listener.id)
      Live::ParticipantTracker.update_metadata(
        room.id,
        listener.id,
        role: "speaker",
        is_muted: false,
        is_video_on: true,
      )

      messages =
        MessageBus.track_publish(Live.room_channel(room.id)) do
          described_class.step_down!(room, listener)
        end

      expect(Live::ParticipantTracker.session_speaker?(room.id, listener.id)).to eq(false)
      metadata = Live::ParticipantTracker.get_metadata(room.id, listener.id)
      expect(metadata[:role]).to eq("participant")
      expect(metadata[:is_muted]).to eq(true)
      expect(metadata[:is_video_on]).to eq(false)
      expect(
        messages.any? { |m| m.data[:type] == "role_change" && m.data[:role] == "participant" },
      ).to eq(true)
    end
  end

  describe ".mute_participant!" do
    it "sets is_muted and broadcasts force_mute without making LiveKit calls on mesh" do
      Live::ParticipantTracker.pin_transport!(room.id, "mesh")
      Live::ParticipantTracker.add(room.id, listener.id)
      Live::ParticipantTracker.update_metadata(
        room.id,
        listener.id,
        role: "speaker",
        is_muted: false,
      )

      messages =
        MessageBus.track_publish(Live.room_channel(room.id)) do
          described_class.mute_participant!(room, listener, acting_user: owner)
        end

      expect(Live::ParticipantTracker.get_metadata(room.id, listener.id)[:is_muted]).to eq(true)
      force_mute = messages.find { |m| m.data[:type] == "force_mute" }
      expect(force_mute).to be_present
      expect(force_mute.data[:user_id]).to eq(listener.id)
      expect(force_mute.user_ids).to eq([listener.id])
    end

    it "mutes published microphone tracks on LiveKit when pinned to livekit" do
      SiteSetting.live_livekit_url = "wss://livekit.example.com"
      SiteSetting.live_livekit_api_key = "lk_key"
      SiteSetting.live_livekit_api_secret = "lk_secret"
      Live::ParticipantTracker.pin_transport!(room.id, "livekit")
      Live::ParticipantTracker.add(room.id, listener.id)

      get_stub =
        stub_request(
          :post,
          "https://livekit.example.com/twirp/livekit.RoomService/GetParticipant",
        ).to_return(
          status: 200,
          body: {
            identity: listener.id.to_s,
            tracks: [
              { sid: "TR_mic1", type: "AUDIO", source: "MICROPHONE", muted: false },
              { sid: "TR_cam1", type: "VIDEO", source: "CAMERA", muted: false },
            ],
          }.to_json,
        )
      mute_stub =
        stub_request(
          :post,
          "https://livekit.example.com/twirp/livekit.RoomService/MutePublishedTrack",
        )
          .with do |req|
            body = JSON.parse(req.body)
            body["identity"] == listener.id.to_s && body["track_sid"] == "TR_mic1" &&
              body["muted"] == true
          end
          .to_return(status: 200, body: "{}")

      described_class.mute_participant!(room, listener, acting_user: owner)

      expect(get_stub).to have_been_requested.once
      expect(mute_stub).to have_been_requested.once
    end
  end

  describe ".sync_room_type_change!" do
    it "resets non-speaker media metadata when switching open to stage" do
      open_room =
        Fabricate(:live_room, creator: owner, public: true, room_type: Live::Room::ROOM_TYPE_OPEN)
      Live::ParticipantTracker.add(open_room.id, listener.id)
      Live::ParticipantTracker.update_metadata(
        open_room.id,
        listener.id,
        role: "participant",
        is_muted: false,
        is_video_on: true,
        is_screen_sharing: true,
      )

      open_room.update!(room_type: Live::Room::ROOM_TYPE_STAGE)
      described_class.sync_room_type_change!(open_room)

      metadata = Live::ParticipantTracker.get_metadata(open_room.id, listener.id)
      expect(metadata[:is_muted]).to eq(true)
      expect(metadata[:is_video_on]).to eq(false)
      expect(metadata[:is_screen_sharing]).to eq(false)
    ensure
      Live::ParticipantTracker.clear(open_room.id)
    end

    it "clears raised hands, invitations, and session speakers when switching stage to open" do
      Live::ParticipantTracker.add(room.id, listener.id)
      Live::ParticipantTracker.raise_hand(room.id, listener.id)
      Live::ParticipantTracker.set_speak_invitation(room.id, listener.id, inviter: owner)
      described_class.grant_session_speaker!(room, listener)

      room.update!(room_type: Live::Room::ROOM_TYPE_OPEN)
      described_class.sync_room_type_change!(room)

      metadata = Live::ParticipantTracker.get_metadata(room.id, listener.id)
      expect(metadata[:hand_raised_at]).to be_nil
      expect(metadata[:speak_invited_at]).to be_nil
      expect(Live::ParticipantTracker.speak_invitation(room.id, listener.id)).to be_nil
      expect(Live::ParticipantTracker.session_speaker?(room.id, listener.id)).to eq(false)
    end
  end
end

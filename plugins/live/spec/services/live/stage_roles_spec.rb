# frozen_string_literal: true
require "rails_helper"

RSpec.describe Live::StageRoles do
  fab!(:owner, :user)
  fab!(:listener, :user)
  fab!(:other, :user)
  fab!(:room) do
    Fabricate(:live_room, creator: owner, public: true, room_type: Live::Room::ROOM_TYPE_STAGE)
  end

  before do
    SiteSetting.live_enabled = true
    SiteSetting.live_allowed_groups =
      "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"
  end

  after { Live::ParticipantTracker.clear(room.id) }

  describe ".assign!" do
    it "creates a permanent speaker by default" do
      membership = described_class.assign!(room, listener, role: Live::RoomMembership::ROLE_SPEAKER)

      expect(membership).to have_attributes(speaker?: true, session_only: false, fallback_role: nil)
    end

    it "marks a session-only speaker with no fallback when the user had no membership" do
      membership =
        described_class.assign!(
          room,
          listener,
          role: Live::RoomMembership::ROLE_SPEAKER,
          session_only: true,
        )

      expect(membership).to have_attributes(speaker?: true, session_only: true, fallback_role: nil)
    end

    it "remembers the previous role of an existing member" do
      room.room_memberships.create!(user: listener, role: Live::RoomMembership::ROLE_PARTICIPANT)

      membership =
        described_class.assign!(
          room,
          listener,
          role: Live::RoomMembership::ROLE_SPEAKER,
          session_only: true,
        )

      expect(membership.fallback_role).to eq(Live::RoomMembership::ROLE_PARTICIPANT)
    end

    it "never downgrades a permanent speaker or moderator to session-only" do
      room.room_memberships.create!(user: listener, role: Live::RoomMembership::ROLE_SPEAKER)

      membership =
        described_class.assign!(
          room,
          listener,
          role: Live::RoomMembership::ROLE_SPEAKER,
          session_only: true,
        )

      expect(membership).to have_attributes(speaker?: true, session_only: false)
    end

    it "never makes a moderator session-only" do
      membership =
        described_class.assign!(
          room,
          listener,
          role: Live::RoomMembership::ROLE_MODERATOR,
          session_only: true,
        )

      expect(membership).to have_attributes(moderator?: true, session_only: false)
    end

    it "makes an explicit permanent assignment override a session-only grant" do
      described_class.assign!(
        room,
        listener,
        role: Live::RoomMembership::ROLE_SPEAKER,
        session_only: true,
      )
      membership = described_class.assign!(room, listener, role: Live::RoomMembership::ROLE_SPEAKER)

      expect(membership).to have_attributes(session_only: false, fallback_role: nil)
    end
  end

  describe ".clear_session_speakers!" do
    fab!(:permanent, :user)

    before do
      described_class.assign!(room, permanent, role: Live::RoomMembership::ROLE_SPEAKER)
      described_class.assign!(
        room,
        listener,
        role: Live::RoomMembership::ROLE_SPEAKER,
        session_only: true,
      )
      room.room_memberships.create!(user: other, role: Live::RoomMembership::ROLE_PARTICIPANT)
      described_class.assign!(
        room,
        other,
        role: Live::RoomMembership::ROLE_SPEAKER,
        session_only: true,
      )
    end

    it "deletes created-for-the-session rows, reverts upgraded ones and keeps permanent ones" do
      described_class.clear_session_speakers!(room.id)

      expect(room.room_memberships.find_by(user: listener)).to be_nil
      expect(room.room_memberships.find_by(user: other)).to have_attributes(
        role: Live::RoomMembership::ROLE_PARTICIPANT,
        session_only: false,
        fallback_role: nil,
      )
      expect(room.room_memberships.find_by(user: permanent)).to be_speaker
    end

    it "can be scoped to one user" do
      described_class.clear_session_speakers!(room.id, user_id: listener.id)

      expect(room.room_memberships.find_by(user: listener)).to be_nil
      expect(room.room_memberships.find_by(user: other)).to be_speaker
    end
  end

  describe ".sync_participant" do
    before do
      Live::ParticipantTracker.add(room.id, listener.id)
      Live::ParticipantTracker.update_metadata(
        room.id,
        listener.id,
        role: "speaker",
        is_muted: false,
        is_video_on: true,
        is_screen_sharing: true,
      )
    end

    it "resets published state when a speaker is demoted to listener" do
      membership =
        room.room_memberships.create!(user: listener, role: Live::RoomMembership::ROLE_SPEAKER)

      messages =
        MessageBus.track_publish(Live.room_channel(room.id)) do
          described_class.remove!(room, membership)
        end

      metadata = Live::ParticipantTracker.get_metadata(room.id, listener.id)
      expect(metadata).to include(
        role: "participant",
        is_muted: true,
        is_video_on: false,
        is_screen_sharing: false,
      )
      expect(messages.map { |m| m.data[:type] }).to include("role_change", "participants")
    end

    it "updates the SFU permissions of a present participant, and only of a present one" do
      membership =
        room.room_memberships.create!(user: listener, role: Live::RoomMembership::ROLE_SPEAKER)
      Live::Livekit::RoomServiceClient.expects(:update_participant).with(room, listener).once

      described_class.remove!(room, membership)

      Live::ParticipantTracker.remove(room.id, listener.id)
      Live::Livekit::RoomServiceClient.expects(:update_participant).never

      described_class.assign!(room, listener, role: Live::RoomMembership::ROLE_SPEAKER)
    end

    it "resets published state on an update to participant" do
      room.room_memberships.create!(user: listener, role: Live::RoomMembership::ROLE_SPEAKER)

      described_class.assign!(room, listener, role: Live::RoomMembership::ROLE_PARTICIPANT)

      expect(Live::ParticipantTracker.get_metadata(room.id, listener.id)).to include(
        is_muted: true,
        is_video_on: false,
        is_screen_sharing: false,
      )
    end

    it "keeps published state when the new role can still speak" do
      described_class.assign!(room, listener, role: Live::RoomMembership::ROLE_MODERATOR)

      expect(Live::ParticipantTracker.get_metadata(room.id, listener.id)).to include(
        role: "moderator",
        is_muted: false,
        is_video_on: true,
      )
    end

    it "does not reset anything in an open room" do
      room.update!(room_type: Live::Room::ROOM_TYPE_OPEN)
      membership =
        room.room_memberships.create!(user: listener, role: Live::RoomMembership::ROLE_SPEAKER)

      described_class.remove!(room, membership)

      expect(Live::ParticipantTracker.get_metadata(room.id, listener.id)).to include(
        is_muted: false,
        is_video_on: true,
      )
    end

    it "clears the hand and invitation when promoting" do
      Live::ParticipantTracker.raise_hand(room.id, listener.id)
      Live::ParticipantTracker.invite_to_speak(room.id, listener.id)

      described_class.assign!(room, listener, role: Live::RoomMembership::ROLE_SPEAKER)

      metadata = Live::ParticipantTracker.get_metadata(room.id, listener.id)
      expect(metadata).not_to include(:hand_raised_at)
      expect(metadata).not_to include(:speak_invited_at)
    end
  end
end

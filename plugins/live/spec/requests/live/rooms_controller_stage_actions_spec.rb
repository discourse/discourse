# frozen_string_literal: true

require "rails_helper"

RSpec.describe Live::RoomsController do
  fab!(:admin)
  fab!(:room_owner) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:listener) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:other_listener) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:room) do
    Fabricate(:live_room, creator: room_owner, public: true, room_type: Live::Room::ROOM_TYPE_STAGE)
  end

  before do
    SiteSetting.live_enabled = true
    SiteSetting.live_allowed_groups =
      "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"
    SiteSetting.live_create_room_allowed_groups = "#{Group::AUTO_GROUPS[:trust_level_2]}"
    Live::ParticipantTracker.add(room.id, listener.id)
    Live::ParticipantTracker.update_metadata(
      room.id,
      listener.id,
      role: "participant",
      is_muted: true,
    )
    @listener_session_id =
      Live::ParticipantTracker.create_participant_session!(room.id, listener.id)
  end

  after { Live::ParticipantTracker.clear(room.id) }

  describe "speak invitations" do
    it "lets a moderator invite a present listener and lets the listener accept as a session-only speaker" do
      sign_in(room_owner)

      messages =
        MessageBus.track_publish(Live.room_channel(room.id)) do
          post "/live/rooms/#{room.id}/invite_to_speak.json", params: { user_id: listener.id }
        end

      expect(response.status).to eq(204)
      expect(Live::ParticipantTracker.speak_invitation(room.id, listener.id)).to be_present
      invite_msg = messages.find { |m| m.data[:type] == "speak_invitation" }
      expect(invite_msg.data[:invited]).to eq(true)
      expect(invite_msg.data[:user_id]).to eq(listener.id)

      sign_in(listener)
      post "/live/rooms/#{room.id}/accept_speak_invitation.json",
           params: {
             participant_session_id: @listener_session_id,
           }

      expect(response.status).to eq(204)
      expect(room.room_memberships.where(user: listener)).to be_empty
      expect(Live::ParticipantTracker.session_speaker?(room.id, listener.id)).to eq(true)
      expect(Live::ParticipantTracker.speak_invitation(room.id, listener.id)).to be_nil
      expect(Live::ParticipantTracker.get_metadata(room.id, listener.id)[:role]).to eq("speaker")
    end

    it "blocks accepting an invitation without a pending invite to prevent self-promotion" do
      sign_in(listener)

      post "/live/rooms/#{room.id}/accept_speak_invitation.json",
           params: {
             participant_session_id: @listener_session_id,
           }

      expect(response.status).to eq(403)
      expect(room.room_memberships.find_by(user: listener)).to be_nil
    end

    it "lets the listener decline their own invitation" do
      Live::ParticipantTracker.set_speak_invitation(room.id, listener.id, inviter: room_owner)
      sign_in(listener)

      messages =
        MessageBus.track_publish(Live.room_channel(room.id)) do
          delete "/live/rooms/#{room.id}/invite_to_speak.json",
                 params: {
                   participant_session_id: @listener_session_id,
                 }
        end

      expect(response.status).to eq(204)
      expect(Live::ParticipantTracker.speak_invitation(room.id, listener.id)).to be_nil
      msg = messages.find { |m| m.data[:type] == "speak_invitation" }
      expect(msg.data[:invited]).to eq(false)
      expect(msg.data[:reason]).to eq("declined")
    end

    it "lets a moderator withdraw an invitation" do
      Live::ParticipantTracker.set_speak_invitation(room.id, listener.id, inviter: room_owner)
      sign_in(room_owner)

      messages =
        MessageBus.track_publish(Live.room_channel(room.id)) do
          delete "/live/rooms/#{room.id}/invite_to_speak.json", params: { user_id: listener.id }
        end

      expect(response.status).to eq(204)
      msg = messages.find { |m| m.data[:type] == "speak_invitation" }
      expect(msg.data[:invited]).to eq(false)
      expect(msg.data[:reason]).to eq("withdrawn")
    end

    it "still allows moderator invitations when speak requests are paused" do
      room.update!(speak_requests_enabled: false)
      sign_in(room_owner)

      post "/live/rooms/#{room.id}/invite_to_speak.json", params: { user_id: listener.id }
      expect(response.status).to eq(204)
    end
  end

  describe "speak_requests_enabled and dismissal cooldown" do
    it "rejects hand raises when speak_requests_enabled is false" do
      room.update!(speak_requests_enabled: false)
      sign_in(listener)

      post "/live/rooms/#{room.id}/request_to_speak.json",
           params: {
             participant_session_id: @listener_session_id,
           }

      expect(response.status).to eq(403)
      expect(response.parsed_body["errors"]).to include(
        I18n.t("live.errors.speak_requests_disabled"),
      )
    end

    it "enforces a 30-second cooldown after a moderator dismisses a raised hand" do
      Live::ParticipantTracker.raise_hand(room.id, listener.id)
      sign_in(room_owner)
      delete "/live/rooms/#{room.id}/request_to_speak.json", params: { user_id: listener.id }
      expect(response.status).to eq(204)

      sign_in(listener)
      post "/live/rooms/#{room.id}/request_to_speak.json",
           params: {
             participant_session_id: @listener_session_id,
           }

      expect(response.status).to eq(429)
      expect(Live::ParticipantTracker.get_metadata(room.id, listener.id)[:hand_raised_at]).to be_nil
    end

    it "does not enforce a cooldown when the listener withdraws their own hand" do
      Live::ParticipantTracker.raise_hand(room.id, listener.id)
      sign_in(listener)
      delete "/live/rooms/#{room.id}/request_to_speak.json",
             params: {
               participant_session_id: @listener_session_id,
             }
      expect(response.status).to eq(204)

      post "/live/rooms/#{room.id}/request_to_speak.json",
           params: {
             participant_session_id: @listener_session_id,
           }

      expect(response.status).to eq(204)
      expect(Live::ParticipantTracker.get_metadata(room.id, listener.id)[:hand_raised_at]).to be_a(
        Float,
      )
    end
  end

  describe "#step_down" do
    it "lets a stage speaker step down to listener" do
      Live::StageRoles.grant_session_speaker!(room, listener)
      sign_in(listener)

      post "/live/rooms/#{room.id}/step_down.json",
           params: {
             participant_session_id: @listener_session_id,
           }

      expect(response.status).to eq(204)
      expect(room.room_memberships.find_by(user: listener)).to be_nil
      expect(Live::ParticipantTracker.get_metadata(room.id, listener.id)[:role]).to eq(
        "participant",
      )
    end

    it "returns 403 for a listener or room moderator" do
      sign_in(listener)
      post "/live/rooms/#{room.id}/step_down.json",
           params: {
             participant_session_id: @listener_session_id,
           }
      expect(response.status).to eq(403)

      Live::ParticipantTracker.add(room.id, room_owner.id)
      owner_session = Live::ParticipantTracker.create_participant_session!(room.id, room_owner.id)
      sign_in(room_owner)
      post "/live/rooms/#{room.id}/step_down.json",
           params: {
             participant_session_id: owner_session,
           }
      expect(response.status).to eq(403)
    end
  end

  describe "#mute_participant" do
    it "lets a room manager remotely mute a present speaker" do
      Live::StageRoles.assign_role!(room, listener, role: Live::RoomMembership::ROLE_SPEAKER)
      Live::ParticipantTracker.update_metadata(
        room.id,
        listener.id,
        role: "speaker",
        is_muted: false,
      )
      sign_in(room_owner)

      messages =
        MessageBus.track_publish(Live.room_channel(room.id)) do
          post "/live/rooms/#{room.id}/mute_participant.json", params: { user_id: listener.id }
        end

      expect(response.status).to eq(204)
      expect(Live::ParticipantTracker.get_metadata(room.id, listener.id)[:is_muted]).to eq(true)
      expect(
        messages.any? { |m| m.data[:type] == "force_mute" && m.data[:user_id] == listener.id },
      ).to eq(true)
    end

    it "forbids non-managers from muting other participants" do
      sign_in(other_listener)

      post "/live/rooms/#{room.id}/mute_participant.json", params: { user_id: listener.id }

      expect(response.status).to eq(403)
    end
  end

  describe "join & leave stage semantics" do
    it "assigns moderator metadata to a site admin joining a stage room without a membership" do
      sign_in(admin)

      post "/live/rooms/#{room.id}/join.json"

      expect(response.status).to eq(200)
      expect(Live::ParticipantTracker.get_metadata(room.id, admin.id)[:role]).to eq("moderator")
    end

    it "marks a joining stage listener as muted in metadata" do
      sign_in(other_listener)

      post "/live/rooms/#{room.id}/join.json"

      expect(response.status).to eq(200)
      metadata = Live::ParticipantTracker.get_metadata(room.id, other_listener.id)
      expect(metadata[:role]).to eq("participant")
      expect(metadata[:is_muted]).to eq(true)
    end

    it "ends session-only speaker grants when the last participant leaves" do
      Live::StageRoles.grant_session_speaker!(room, listener)
      sign_in(listener)

      delete "/live/rooms/#{room.id}/leave.json",
             params: {
               participant_session_id: @listener_session_id,
             }

      expect(response.status).to eq(204)
      expect(Live::ParticipantTracker.session_speaker?(room.id, listener.id)).to eq(false)
    end
  end
end

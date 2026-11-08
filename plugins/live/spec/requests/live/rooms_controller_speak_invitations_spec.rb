# frozen_string_literal: true
require "rails_helper"

RSpec.describe Live::RoomsController do
  fab!(:owner) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:listener) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:other_listener) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:room) do
    Fabricate(:live_room, creator: owner, public: true, room_type: Live::Room::ROOM_TYPE_STAGE)
  end

  before do
    SiteSetting.live_enabled = true
    SiteSetting.live_allowed_groups =
      "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"
    SiteSetting.live_create_room_allowed_groups = "#{Group::AUTO_GROUPS[:trust_level_2]}"
    Live::ParticipantTracker.add(room.id, listener.id)
    @listener_session_id =
      Live::ParticipantTracker.create_participant_session!(room.id, listener.id)
  end

  after { Live::ParticipantTracker.clear(room.id) }

  describe "raise hand cooldown" do
    it "blocks re-raising for a while after a moderator dismisses the hand" do
      Live::ParticipantTracker.raise_hand(room.id, listener.id)
      sign_in(owner)
      delete "/live/rooms/#{room.id}/request_to_speak.json", params: { user_id: listener.id }
      expect(response.status).to eq(204)

      sign_in(listener)
      post "/live/rooms/#{room.id}/request_to_speak.json",
           params: {
             participant_session_id: @listener_session_id,
           }

      expect(response.status).to eq(429)
      expect(Live::ParticipantTracker.get_metadata(room.id, listener.id)).not_to include(
        :hand_raised_at,
      )
    end

    it "does not start a cooldown when the listener withdraws their own hand" do
      Live::ParticipantTracker.raise_hand(room.id, listener.id)
      sign_in(listener)
      delete "/live/rooms/#{room.id}/request_to_speak.json",
             params: {
               participant_session_id: @listener_session_id,
             }

      post "/live/rooms/#{room.id}/request_to_speak.json",
           params: {
             participant_session_id: @listener_session_id,
           }

      expect(response.status).to eq(204)
    end

    it "lets the listener ask again once the cooldown has passed" do
      Live::ParticipantTracker.start_hand_cooldown(room.id, listener.id)
      Live::ParticipantTracker.send(:redis).del(
        Live::ParticipantTracker.send(:hand_cooldown_key, room.id, listener.id),
      )
      sign_in(listener)

      post "/live/rooms/#{room.id}/request_to_speak.json",
           params: {
             participant_session_id: @listener_session_id,
           }

      expect(response.status).to eq(204)
    end
  end

  describe "speak requests disabled" do
    before { room.update!(speak_requests_enabled: false) }

    it "rejects a request to speak" do
      sign_in(listener)

      post "/live/rooms/#{room.id}/request_to_speak.json",
           params: {
             participant_session_id: @listener_session_id,
           }

      expect(response.status).to eq(403)
    end

    it "still lets a moderator invite the listener" do
      sign_in(owner)

      post "/live/rooms/#{room.id}/speak_invitation.json", params: { user_id: listener.id }

      expect(response.status).to eq(204)
    end
  end

  describe "#invite_to_speak" do
    it "records the invitation and broadcasts it" do
      sign_in(owner)

      messages =
        MessageBus.track_publish(Live.room_channel(room.id)) do
          post "/live/rooms/#{room.id}/speak_invitation.json", params: { user_id: listener.id }
        end

      expect(response.status).to eq(204)
      expect(
        Live::ParticipantTracker.get_metadata(room.id, listener.id)[:speak_invited_at],
      ).to be_a(Float)
      message = messages.find { |m| m.data[:type] == "speak_invitation" }
      expect(message.data).to include(user_id: listener.id, invited: true, reason: "invited")
      expect(messages.find { |m| m.data[:type] == "participants" }).to be_present
    end

    it "publishes nothing on a repeat invitation" do
      Live::ParticipantTracker.invite_to_speak(room.id, listener.id)
      sign_in(owner)

      messages =
        MessageBus.track_publish(Live.room_channel(room.id)) do
          post "/live/rooms/#{room.id}/speak_invitation.json", params: { user_id: listener.id }
        end

      expect(response.status).to eq(204)
      expect(messages).to be_empty
    end

    it "returns 403 for a non-moderator" do
      Live::ParticipantTracker.add(room.id, other_listener.id)
      sign_in(other_listener)

      post "/live/rooms/#{room.id}/speak_invitation.json", params: { user_id: listener.id }

      expect(response.status).to eq(403)
      expect(Live::ParticipantTracker.get_metadata(room.id, listener.id)).not_to include(
        :speak_invited_at,
      )
    end

    it "rejects inviting someone who is not in the call" do
      sign_in(owner)

      post "/live/rooms/#{room.id}/speak_invitation.json", params: { user_id: other_listener.id }

      expect(response.status).to eq(400)
    end

    it "rejects inviting someone who can already speak" do
      Live::ParticipantTracker.add(room.id, other_listener.id)
      room.room_memberships.create!(user: other_listener, role: Live::RoomMembership::ROLE_SPEAKER)
      sign_in(owner)

      post "/live/rooms/#{room.id}/speak_invitation.json", params: { user_id: other_listener.id }

      expect(response.status).to eq(400)
    end

    it "rejects invitations in an open room" do
      room.update!(room_type: Live::Room::ROOM_TYPE_OPEN)
      sign_in(owner)

      post "/live/rooms/#{room.id}/speak_invitation.json", params: { user_id: listener.id }

      expect(response.status).to eq(400)
    end
  end

  describe "#accept_speak_invitation" do
    it "makes the invited listener a session-only speaker" do
      Live::ParticipantTracker.invite_to_speak(room.id, listener.id)
      sign_in(listener)

      messages =
        MessageBus.track_publish(Live.room_channel(room.id)) do
          post "/live/rooms/#{room.id}/speak_invitation/accept.json",
               params: {
                 participant_session_id: @listener_session_id,
               }
        end

      expect(response.status).to eq(204)
      membership = room.room_memberships.find_by(user: listener)
      expect(membership).to have_attributes(speaker?: true, session_only: true)
      metadata = Live::ParticipantTracker.get_metadata(room.id, listener.id)
      expect(metadata[:role]).to eq("speaker")
      expect(metadata).not_to include(:speak_invited_at)
      expect(messages.map { |m| m.data[:type] }).to include("role_change", "speak_invitation")
    end

    it "refuses to promote someone who was not invited" do
      sign_in(listener)

      post "/live/rooms/#{room.id}/speak_invitation/accept.json",
           params: {
             participant_session_id: @listener_session_id,
           }

      expect(response.status).to eq(403)
      expect(room.room_memberships.find_by(user: listener)).to be_nil
    end

    it "requires a valid participant session" do
      Live::ParticipantTracker.invite_to_speak(room.id, listener.id)
      sign_in(listener)

      post "/live/rooms/#{room.id}/speak_invitation/accept.json"

      expect(response.status).to eq(403)
      expect(room.room_memberships.find_by(user: listener)).to be_nil
    end
  end

  describe "#decline_speak_invitation" do
    it "lets the invitee decline" do
      Live::ParticipantTracker.invite_to_speak(room.id, listener.id)
      sign_in(listener)

      messages =
        MessageBus.track_publish(Live.room_channel(room.id)) do
          delete "/live/rooms/#{room.id}/speak_invitation.json",
                 params: {
                   participant_session_id: @listener_session_id,
                 }
        end

      expect(response.status).to eq(204)
      expect(Live::ParticipantTracker.get_metadata(room.id, listener.id)).not_to include(
        :speak_invited_at,
      )
      expect(messages.find { |m| m.data[:type] == "speak_invitation" }.data[:reason]).to eq(
        "declined",
      )
    end

    it "lets a moderator withdraw the invitation" do
      Live::ParticipantTracker.invite_to_speak(room.id, listener.id)
      sign_in(owner)

      delete "/live/rooms/#{room.id}/speak_invitation.json", params: { user_id: listener.id }

      expect(response.status).to eq(204)
      expect(Live::ParticipantTracker.speak_invited?(room.id, listener.id)).to eq(false)
    end

    it "returns 403 when a listener tries to withdraw someone else's invitation" do
      Live::ParticipantTracker.invite_to_speak(room.id, listener.id)
      Live::ParticipantTracker.add(room.id, other_listener.id)
      sign_in(other_listener)

      delete "/live/rooms/#{room.id}/speak_invitation.json", params: { user_id: listener.id }

      expect(response.status).to eq(403)
      expect(Live::ParticipantTracker.speak_invited?(room.id, listener.id)).to eq(true)
    end
  end

  describe "session-only speakers" do
    before do
      Live::StageRoles.assign!(
        room,
        listener,
        role: Live::RoomMembership::ROLE_SPEAKER,
        session_only: true,
      )
    end

    it "keeps the role when the speaker leaves while others remain" do
      Live::ParticipantTracker.add(room.id, other_listener.id)
      sign_in(listener)

      delete "/live/rooms/#{room.id}/leave.json",
             params: {
               participant_session_id: @listener_session_id,
             }

      expect(response.status).to eq(204)
      expect(room.room_memberships.find_by(user: listener)).to be_speaker
    end

    it "drops the role when the last person leaves" do
      sign_in(listener)

      delete "/live/rooms/#{room.id}/leave.json",
             params: {
               participant_session_id: @listener_session_id,
             }

      expect(response.status).to eq(204)
      expect(room.room_memberships.find_by(user: listener)).to be_nil
    end

    it "drops the role when a moderator kicks the speaker" do
      Live::ParticipantTracker.add(room.id, other_listener.id)
      sign_in(owner)

      delete "/live/rooms/#{room.id}/kick.json", params: { user_id: listener.id }

      expect(response.status).to eq(204)
      expect(room.room_memberships.find_by(user: listener)).to be_nil
    end
  end
end

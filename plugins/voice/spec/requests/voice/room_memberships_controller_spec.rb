# frozen_string_literal: true
require "rails_helper"
require_relative "../../../db/migrate/20241107000000_create_voice_rooms"
require_relative "../../../db/migrate/20260305162426_add_room_type_to_voice_rooms"
require_relative "../../../db/migrate/20260612135211_add_video_enabled_to_voice_rooms"

RSpec.describe Voice::RoomMembershipsController do
  before do
    ActiveRecord::Migration.suppress_messages do
      CreateVoiceRooms.new.change unless ActiveRecord::Base.connection.table_exists?(:voice_rooms)
      unless ActiveRecord::Base.connection.column_exists?(:voice_rooms, :room_type)
        AddRoomTypeToVoiceRooms.new.change
      end
      unless ActiveRecord::Base.connection.column_exists?(:voice_rooms, :video_enabled)
        AddVideoEnabledToVoiceRooms.new.change
      end
    end
    Voice::Room.reset_column_information
  end

  fab!(:staff, :admin)
  fab!(:room_owner) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:room_moderator) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:member) { Fabricate(:user, trust_level: TrustLevel[2]) }

  # In voice_create_room_allowed_groups but with no tie to the room: being
  # allowed to create rooms must not grant control over other people's rooms.
  fab!(:outsider) { Fabricate(:user, trust_level: TrustLevel[2]) }

  fab!(:invitee) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:room) { Fabricate(:voice_room, creator: room_owner, public: false) }

  fab!(:moderator_membership) do
    room.room_memberships.create!(user: room_moderator, role: Voice::RoomMembership::ROLE_MODERATOR)
  end

  fab!(:participant_membership) do
    room.room_memberships.create!(user: member, role: Voice::RoomMembership::ROLE_PARTICIPANT)
  end

  before do
    SiteSetting.voice_enabled = true
    SiteSetting.voice_allowed_groups = Group::AUTO_GROUPS[:everyone]
    SiteSetting.voice_create_room_allowed_groups = "#{Group::AUTO_GROUPS[:trust_level_2]}"
  end

  describe "#index" do
    it "returns 403 for a non-member who can create rooms" do
      sign_in(outsider)

      get "/voice/rooms/#{room.id}/memberships.json"

      expect(response.status).to eq(403)
    end

    it "returns 403 for a plain participant member" do
      sign_in(member)

      get "/voice/rooms/#{room.id}/memberships.json"

      expect(response.status).to eq(403)
    end

    it "returns 403 for anonymous visitors" do
      get "/voice/rooms/#{room.id}/memberships.json"

      expect(response.status).to eq(403)
    end

    it "returns the memberships to the room creator" do
      sign_in(room_owner)

      get "/voice/rooms/#{room.id}/memberships.json"

      expect(response.status).to eq(200)
      user_ids = response.parsed_body["memberships"].map { |membership| membership["user_id"] }
      expect(user_ids).to contain_exactly(room_owner.id, room_moderator.id, member.id)
    end

    it "returns the memberships to a room moderator" do
      sign_in(room_moderator)

      get "/voice/rooms/#{room.id}/memberships.json"

      expect(response.status).to eq(200)
    end

    it "returns the memberships to site staff" do
      sign_in(staff)

      get "/voice/rooms/#{room.id}/memberships.json"

      expect(response.status).to eq(200)
    end
  end

  describe "#create" do
    it "returns 403 for a non-member who can create rooms" do
      sign_in(outsider)

      expect {
        post "/voice/rooms/#{room.id}/memberships.json", params: { user_id: outsider.id }
      }.not_to change { room.room_memberships.count }

      expect(response.status).to eq(403)
    end

    it "returns 403 for a plain participant member" do
      sign_in(member)

      post "/voice/rooms/#{room.id}/memberships.json", params: { user_id: invitee.id }

      expect(response.status).to eq(403)
    end

    it "lets the creator add a member by user_id" do
      sign_in(room_owner)

      post "/voice/rooms/#{room.id}/memberships.json", params: { user_id: invitee.id }

      expect(response.status).to eq(200)
      expect(room.room_memberships.find_by(user_id: invitee.id)).to be_participant
    end

    it "lets the creator add a member by username with a role" do
      sign_in(room_owner)

      post "/voice/rooms/#{room.id}/memberships.json",
           params: {
             username: invitee.username,
             role: "moderator",
           }

      expect(response.status).to eq(200)
      expect(room.room_memberships.find_by(user_id: invitee.id)).to be_moderator
    end

    it "lets a room moderator add a member" do
      sign_in(room_moderator)

      post "/voice/rooms/#{room.id}/memberships.json", params: { user_id: invitee.id }

      expect(response.status).to eq(200)
    end

    it "clears a present listener's raised hand when granting them the speaker role" do
      room.update!(room_type: Voice::Room::ROOM_TYPE_STAGE)
      Voice::ParticipantTracker.add(room.id, member.id)
      Voice::ParticipantTracker.raise_hand(room.id, member.id)
      sign_in(room_owner)

      post "/voice/rooms/#{room.id}/memberships.json",
           params: {
             user_id: member.id,
             role: "speaker",
           }

      expect(response.status).to eq(200)
      metadata = Voice::ParticipantTracker.get_metadata(room.id, member.id)
      expect(metadata[:role]).to eq("speaker")
      expect(metadata[:hand_raised_at]).to be_nil
    end
  end

  describe "#update" do
    it "returns 403 for a non-member who can create rooms" do
      sign_in(outsider)

      expect {
        put "/voice/rooms/#{room.id}/memberships/#{participant_membership.id}.json",
            params: {
              role: "moderator",
            }
      }.not_to change { participant_membership.reload.role }

      expect(response.status).to eq(403)
    end

    it "lets the creator change a member's role" do
      sign_in(room_owner)

      put "/voice/rooms/#{room.id}/memberships/#{participant_membership.id}.json",
          params: {
            role: "speaker",
          }

      expect(response.status).to eq(200)
      expect(participant_membership.reload).to be_speaker
    end

    it "updates the tracked role of a member present in the room" do
      sign_in(room_owner)
      Voice::ParticipantTracker.add(room.id, member.id)

      put "/voice/rooms/#{room.id}/memberships/#{participant_membership.id}.json",
          params: {
            role: "moderator",
          }

      expect(response.status).to eq(200)
      metadata = Voice::ParticipantTracker.get_metadata(room.id, member.id)
      expect(metadata[:role]).to eq("moderator")
    end

    it "clears a present listener's raised hand when promoting them to speaker" do
      room.update!(room_type: Voice::Room::ROOM_TYPE_STAGE)
      Voice::ParticipantTracker.add(room.id, member.id)
      Voice::ParticipantTracker.raise_hand(room.id, member.id)
      sign_in(room_owner)

      put "/voice/rooms/#{room.id}/memberships/#{participant_membership.id}.json",
          params: {
            role: "speaker",
          }

      expect(response.status).to eq(200)
      metadata = Voice::ParticipantTracker.get_metadata(room.id, member.id)
      expect(metadata[:role]).to eq("speaker")
      expect(metadata[:hand_raised_at]).to be_nil
    end

    it "keeps a queued listener's raised hand when their role is set to participant" do
      room.update!(room_type: Voice::Room::ROOM_TYPE_STAGE)
      Voice::ParticipantTracker.add(room.id, member.id)
      Voice::ParticipantTracker.raise_hand(room.id, member.id)
      sign_in(room_owner)

      put "/voice/rooms/#{room.id}/memberships/#{participant_membership.id}.json",
          params: {
            role: "participant",
          }

      expect(response.status).to eq(200)
      metadata = Voice::ParticipantTracker.get_metadata(room.id, member.id)
      expect(metadata[:role]).to eq("participant")
      expect(metadata[:hand_raised_at]).to be_a(Float)
    end
  end

  describe "#destroy" do
    it "returns 403 for a non-member who can create rooms" do
      sign_in(outsider)

      expect {
        delete "/voice/rooms/#{room.id}/memberships/#{participant_membership.id}.json"
      }.not_to change { room.room_memberships.count }

      expect(response.status).to eq(403)
    end

    it "returns 403 for a plain participant member removing another member" do
      sign_in(member)

      delete "/voice/rooms/#{room.id}/memberships/#{moderator_membership.id}.json"

      expect(response.status).to eq(403)
      expect(Voice::RoomMembership.exists?(moderator_membership.id)).to eq(true)
    end

    it "lets the creator remove a member" do
      sign_in(room_owner)

      delete "/voice/rooms/#{room.id}/memberships/#{participant_membership.id}.json"

      expect(response.status).to eq(204)
      expect(Voice::RoomMembership.exists?(participant_membership.id)).to eq(false)
    end

    it "lets site staff remove a member" do
      sign_in(staff)

      delete "/voice/rooms/#{room.id}/memberships/#{participant_membership.id}.json"

      expect(response.status).to eq(204)
    end
  end

  describe "livekit permission sync" do
    before do
      SiteSetting.voice_livekit_url = "wss://livekit.example.com"
      SiteSetting.voice_livekit_api_key = "lk_api_key"
      SiteSetting.voice_livekit_api_secret = "lk_api_secret"
      room.update!(room_type: Voice::Room::ROOM_TYPE_STAGE)
      Voice::ParticipantTracker.pin_transport!(room.id, "livekit")
      Voice::ParticipantTracker.add(room.id, member.id)
      sign_in(room_owner)
    end

    after { Voice::ParticipantTracker.clear(room.id) }

    def update_participant_stub
      stub_request(:post, "https://livekit.example.com/twirp/livekit.RoomService/UpdateParticipant")
    end

    it "grants publishing on the SFU when a present stage listener is promoted" do
      update_participant_stub

      put "/voice/rooms/#{room.id}/memberships/#{participant_membership.id}.json",
          params: {
            role: "speaker",
          }

      expect(response.status).to eq(200)
      expect(
        a_request(
          :post,
          "https://livekit.example.com/twirp/livekit.RoomService/UpdateParticipant",
        ).with do |req|
          body = JSON.parse(req.body)
          body["identity"] == member.id.to_s && body["permission"]["canPublish"] == true &&
            body["permission"]["canSubscribe"] == true
        end,
      ).to have_been_made.once
    end

    it "revokes publishing on the SFU when a present speaker's membership is removed" do
      participant_membership.update!(role: Voice::RoomMembership::ROLE_SPEAKER)
      update_participant_stub

      delete "/voice/rooms/#{room.id}/memberships/#{participant_membership.id}.json"

      expect(response.status).to eq(204)
      expect(
        a_request(
          :post,
          "https://livekit.example.com/twirp/livekit.RoomService/UpdateParticipant",
        ).with do |req|
          body = JSON.parse(req.body)
          body["identity"] == member.id.to_s && body["permission"]["canPublish"] == false
        end,
      ).to have_been_made.once
    end

    it "still succeeds when LiveKit is down" do
      update_participant_stub.to_timeout

      put "/voice/rooms/#{room.id}/memberships/#{participant_membership.id}.json",
          params: {
            role: "speaker",
          }

      expect(response.status).to eq(200)
      expect(participant_membership.reload).to be_speaker
    end

    it "makes zero HTTP calls for a mesh room" do
      Voice::ParticipantTracker.clear_transport_pin(room.id)
      Voice::ParticipantTracker.pin_transport!(room.id, "mesh")
      stub = update_participant_stub

      put "/voice/rooms/#{room.id}/memberships/#{participant_membership.id}.json",
          params: {
            role: "speaker",
          }

      expect(response.status).to eq(200)
      expect(stub).not_to have_been_requested
    end

    it "makes zero HTTP calls when the member is not in the call" do
      Voice::ParticipantTracker.remove(room.id, member.id)
      stub = update_participant_stub

      put "/voice/rooms/#{room.id}/memberships/#{participant_membership.id}.json",
          params: {
            role: "speaker",
          }

      expect(response.status).to eq(200)
      expect(stub).not_to have_been_requested
    end
  end
end

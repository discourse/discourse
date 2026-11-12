# frozen_string_literal: true
require "rails_helper"

RSpec.describe Live::RoomMembershipsController do
  fab!(:staff, :admin)
  fab!(:room_owner) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:room_moderator) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:member) { Fabricate(:user, trust_level: TrustLevel[2]) }

  # In live_create_room_allowed_groups but with no tie to the room: being
  # allowed to create rooms must not grant control over other people's rooms.
  fab!(:outsider) { Fabricate(:user, trust_level: TrustLevel[2]) }

  fab!(:invitee) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:room) { Fabricate(:live_room, creator: room_owner, public: false) }

  fab!(:moderator_membership) do
    room.room_memberships.create!(user: room_moderator, role: Live::RoomMembership::ROLE_MODERATOR)
  end

  fab!(:participant_membership) do
    room.room_memberships.create!(user: member, role: Live::RoomMembership::ROLE_PARTICIPANT)
  end

  before do
    SiteSetting.live_enabled = true
    SiteSetting.live_allowed_groups =
      "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"
    SiteSetting.live_create_room_allowed_groups = "#{Group::AUTO_GROUPS[:trust_level_2]}"
  end

  describe "#index" do
    it "returns 403 for a non-member who can create rooms" do
      sign_in(outsider)

      get "/live/rooms/#{room.id}/memberships.json"

      expect(response.status).to eq(403)
    end

    it "returns 403 for a plain participant member" do
      sign_in(member)

      get "/live/rooms/#{room.id}/memberships.json"

      expect(response.status).to eq(403)
    end

    it "returns 403 for anonymous visitors" do
      get "/live/rooms/#{room.id}/memberships.json"

      expect(response.status).to eq(403)
    end

    it "returns the memberships to the room creator" do
      sign_in(room_owner)

      get "/live/rooms/#{room.id}/memberships.json"

      expect(response.status).to eq(200)
      user_ids = response.parsed_body["memberships"].map { |membership| membership["user_id"] }
      expect(user_ids).to contain_exactly(room_owner.id, room_moderator.id, member.id)
    end

    it "returns the memberships to a room moderator" do
      sign_in(room_moderator)

      get "/live/rooms/#{room.id}/memberships.json"

      expect(response.status).to eq(200)
    end

    it "returns the memberships to site staff" do
      sign_in(staff)

      get "/live/rooms/#{room.id}/memberships.json"

      expect(response.status).to eq(200)
    end
  end

  describe "#create" do
    it "returns 403 for a non-member who can create rooms" do
      sign_in(outsider)

      expect {
        post "/live/rooms/#{room.id}/memberships.json", params: { user_id: outsider.id }
      }.not_to change { room.room_memberships.count }

      expect(response.status).to eq(403)
    end

    it "returns 403 for a plain participant member" do
      sign_in(member)

      post "/live/rooms/#{room.id}/memberships.json", params: { user_id: invitee.id }

      expect(response.status).to eq(403)
    end

    it "lets the creator add a member by user_id" do
      sign_in(room_owner)

      post "/live/rooms/#{room.id}/memberships.json", params: { user_id: invitee.id }

      expect(response.status).to eq(200)
      expect(room.room_memberships.find_by(user_id: invitee.id)).to be_participant
    end

    it "lets the creator add a member by username with a role" do
      sign_in(room_owner)

      post "/live/rooms/#{room.id}/memberships.json",
           params: {
             username: invitee.username,
             role: "moderator",
           }

      expect(response.status).to eq(200)
      expect(room.room_memberships.find_by(user_id: invitee.id)).to be_moderator
    end

    it "lets a room moderator add a member" do
      sign_in(room_moderator)

      post "/live/rooms/#{room.id}/memberships.json", params: { user_id: invitee.id }

      expect(response.status).to eq(200)
    end

    it "clears a present listener's raised hand when granting them the speaker role" do
      room.update!(room_type: Live::Room::ROOM_TYPE_STAGE)
      Live::ParticipantTracker.add(room.id, member.id)
      Live::ParticipantTracker.raise_hand(room.id, member.id)
      sign_in(room_owner)

      post "/live/rooms/#{room.id}/memberships.json",
           params: {
             user_id: member.id,
             role: "speaker",
           }

      expect(response.status).to eq(200)
      metadata = Live::ParticipantTracker.get_metadata(room.id, member.id)
      expect(metadata[:role]).to eq("speaker")
      expect(metadata[:hand_raised_at]).to be_nil
    end
  end

  describe "#update" do
    it "returns 403 for a non-member who can create rooms" do
      sign_in(outsider)

      expect {
        put "/live/rooms/#{room.id}/memberships/#{participant_membership.id}.json",
            params: {
              role: "moderator",
            }
      }.not_to change { participant_membership.reload.role }

      expect(response.status).to eq(403)
    end

    it "lets the creator change a member's role" do
      sign_in(room_owner)

      put "/live/rooms/#{room.id}/memberships/#{participant_membership.id}.json",
          params: {
            role: "speaker",
          }

      expect(response.status).to eq(200)
      expect(participant_membership.reload).to be_speaker
    end

    it "updates the tracked role of a member present in the room" do
      sign_in(room_owner)
      Live::ParticipantTracker.add(room.id, member.id)

      put "/live/rooms/#{room.id}/memberships/#{participant_membership.id}.json",
          params: {
            role: "moderator",
          }

      expect(response.status).to eq(200)
      metadata = Live::ParticipantTracker.get_metadata(room.id, member.id)
      expect(metadata[:role]).to eq("moderator")
    end

    it "clears a present listener's raised hand when promoting them to speaker" do
      room.update!(room_type: Live::Room::ROOM_TYPE_STAGE)
      Live::ParticipantTracker.add(room.id, member.id)
      Live::ParticipantTracker.raise_hand(room.id, member.id)
      sign_in(room_owner)

      put "/live/rooms/#{room.id}/memberships/#{participant_membership.id}.json",
          params: {
            role: "speaker",
          }

      expect(response.status).to eq(200)
      metadata = Live::ParticipantTracker.get_metadata(room.id, member.id)
      expect(metadata[:role]).to eq("speaker")
      expect(metadata[:hand_raised_at]).to be_nil
    end

    it "keeps a queued listener's raised hand when their role is set to participant" do
      room.update!(room_type: Live::Room::ROOM_TYPE_STAGE)
      Live::ParticipantTracker.add(room.id, member.id)
      Live::ParticipantTracker.raise_hand(room.id, member.id)
      sign_in(room_owner)

      put "/live/rooms/#{room.id}/memberships/#{participant_membership.id}.json",
          params: {
            role: "participant",
          }

      expect(response.status).to eq(200)
      metadata = Live::ParticipantTracker.get_metadata(room.id, member.id)
      expect(metadata[:role]).to eq("participant")
      expect(metadata[:hand_raised_at]).to be_a(Float)
    end
  end

  describe "#destroy" do
    it "returns 403 for a non-member who can create rooms" do
      sign_in(outsider)

      expect {
        delete "/live/rooms/#{room.id}/memberships/#{participant_membership.id}.json"
      }.not_to change { room.room_memberships.count }

      expect(response.status).to eq(403)
    end

    it "returns 403 for a plain participant member removing another member" do
      sign_in(member)

      delete "/live/rooms/#{room.id}/memberships/#{moderator_membership.id}.json"

      expect(response.status).to eq(403)
      expect(Live::RoomMembership.exists?(moderator_membership.id)).to eq(true)
    end

    it "lets the creator remove a member" do
      sign_in(room_owner)

      delete "/live/rooms/#{room.id}/memberships/#{participant_membership.id}.json"

      expect(response.status).to eq(204)
      expect(Live::RoomMembership.exists?(participant_membership.id)).to eq(false)
    end

    it "lets site staff remove a member" do
      sign_in(staff)

      delete "/live/rooms/#{room.id}/memberships/#{participant_membership.id}.json"

      expect(response.status).to eq(204)
    end
  end

  describe "livekit permission sync" do
    before do
      SiteSetting.live_livekit_url = "wss://livekit.example.com"
      SiteSetting.live_livekit_api_key = "lk_api_key"
      SiteSetting.live_livekit_api_secret = "lk_api_secret"
      room.update!(room_type: Live::Room::ROOM_TYPE_STAGE)
      Live::ParticipantTracker.pin_transport!(room.id, "livekit")
      Live::ParticipantTracker.add(room.id, member.id)
      sign_in(room_owner)
    end

    after { Live::ParticipantTracker.clear(room.id) }

    def update_participant_stub
      stub_request(:post, "https://livekit.example.com/twirp/livekit.RoomService/UpdateParticipant")
    end

    it "grants publishing on the SFU when a present stage listener is promoted" do
      update_participant_stub

      put "/live/rooms/#{room.id}/memberships/#{participant_membership.id}.json",
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
      participant_membership.update!(role: Live::RoomMembership::ROLE_SPEAKER)
      update_participant_stub

      delete "/live/rooms/#{room.id}/memberships/#{participant_membership.id}.json"

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

      put "/live/rooms/#{room.id}/memberships/#{participant_membership.id}.json",
          params: {
            role: "speaker",
          }

      expect(response.status).to eq(200)
      expect(participant_membership.reload).to be_speaker
    end

    it "makes zero HTTP calls for a mesh room" do
      Live::ParticipantTracker.clear_transport_pin(room.id)
      Live::ParticipantTracker.pin_transport!(room.id, "mesh")
      stub = update_participant_stub

      put "/live/rooms/#{room.id}/memberships/#{participant_membership.id}.json",
          params: {
            role: "speaker",
          }

      expect(response.status).to eq(200)
      expect(stub).not_to have_been_requested
    end

    it "makes zero HTTP calls when the member is not in the call" do
      Live::ParticipantTracker.remove(room.id, member.id)
      stub = update_participant_stub

      put "/live/rooms/#{room.id}/memberships/#{participant_membership.id}.json",
          params: {
            role: "speaker",
          }

      expect(response.status).to eq(200)
      expect(stub).not_to have_been_requested
    end
  end
end

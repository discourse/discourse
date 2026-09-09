# frozen_string_literal: true
require "rails_helper"
require_relative "../../../db/migrate/20241107000000_create_voice_rooms"
require_relative "../../../db/migrate/20260305162426_add_room_type_to_voice_rooms"
require_relative "../../../db/migrate/20260612135211_add_video_enabled_to_voice_rooms"

RSpec.describe Voice::RoomsController do
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
  fab!(:listener) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:other_listener) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:room_speaker) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:room_moderator) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:room) { Fabricate(:voice_room, creator: room_owner, public: true) }

  fab!(:speaker_membership) do
    room.room_memberships.create!(user: room_speaker, role: Voice::RoomMembership::ROLE_SPEAKER)
  end

  fab!(:moderator_membership) do
    room.room_memberships.create!(user: room_moderator, role: Voice::RoomMembership::ROLE_MODERATOR)
  end

  before do
    SiteSetting.voice_enabled = true
    SiteSetting.voice_allowed_groups =
      "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"
    SiteSetting.voice_create_room_allowed_groups = "#{Group::AUTO_GROUPS[:trust_level_2]}"
    room.update!(room_type: Voice::Room::ROOM_TYPE_STAGE)
    Voice::ParticipantTracker.add(room.id, listener.id)
    @listener_session_id =
      Voice::ParticipantTracker.create_participant_session!(room.id, listener.id)
  end

  after { Voice::ParticipantTracker.clear(room.id) }

  describe "#request_to_speak" do
    it "raises a present stage listener's hand and broadcasts the raise plus the roster" do
      sign_in(listener)

      messages =
        MessageBus.track_publish(Voice.room_channel(room.id)) do
          post "/voice/rooms/#{room.id}/request_to_speak.json",
               params: {
                 participant_session_id: @listener_session_id,
               }
        end

      expect(response.status).to eq(204)

      metadata = Voice::ParticipantTracker.get_metadata(room.id, listener.id)
      expect(metadata[:hand_raised_at]).to be_a(Float)

      hand_message = messages.find { |message| message.data[:type] == "hand_raise" }
      expect(hand_message).to be_present
      expect(hand_message.data[:room_id]).to eq(room.id)
      expect(hand_message.data[:user_id]).to eq(listener.id)
      expect(hand_message.data[:raised]).to eq(true)
      expect(hand_message.data[:raised_at]).to eq(metadata[:hand_raised_at])
      expect(hand_message.data[:reason]).to eq("raised")

      expect(messages.find { |message| message.data[:type] == "participants" }).to be_present
    end

    it "keeps the original timestamp and publishes nothing on a repeat request" do
      sign_in(listener)
      post "/voice/rooms/#{room.id}/request_to_speak.json",
           params: {
             participant_session_id: @listener_session_id,
           }
      original = Voice::ParticipantTracker.get_metadata(room.id, listener.id)[:hand_raised_at]

      messages =
        MessageBus.track_publish(Voice.room_channel(room.id)) do
          post "/voice/rooms/#{room.id}/request_to_speak.json",
               params: {
                 participant_session_id: @listener_session_id,
               }
        end

      expect(response.status).to eq(204)
      expect(Voice::ParticipantTracker.get_metadata(room.id, listener.id)[:hand_raised_at]).to eq(
        original,
      )
      expect(messages).to be_empty
    end

    it "returns 403 for a stage speaker, who can already speak" do
      Voice::ParticipantTracker.add(room.id, room_speaker.id)
      sign_in(room_speaker)

      post "/voice/rooms/#{room.id}/request_to_speak.json"

      expect(response.status).to eq(403)
    end

    it "returns 403 for a room moderator, who can already speak" do
      Voice::ParticipantTracker.add(room.id, room_moderator.id)
      sign_in(room_moderator)

      post "/voice/rooms/#{room.id}/request_to_speak.json"

      expect(response.status).to eq(403)
    end

    it "returns 403 for an admin, who can already speak" do
      Voice::ParticipantTracker.add(room.id, staff.id)
      sign_in(staff)

      post "/voice/rooms/#{room.id}/request_to_speak.json"

      expect(response.status).to eq(403)
    end

    it "returns 403 in an open room, where everyone can already speak" do
      room.update!(room_type: Voice::Room::ROOM_TYPE_OPEN)
      sign_in(listener)

      post "/voice/rooms/#{room.id}/request_to_speak.json"

      expect(response.status).to eq(403)
    end

    it "returns 403 with a session message for a stage listener who is not in the call" do
      # Leaving revokes the participant session, so the retained session id no
      # longer authorizes a hand raise.
      Voice::ParticipantTracker.remove(room.id, listener.id)
      sign_in(listener)

      post "/voice/rooms/#{room.id}/request_to_speak.json",
           params: {
             participant_session_id: @listener_session_id,
           }

      expect(response.status).to eq(403)
      expect(response.parsed_body["errors"]).to include(
        I18n.t("voice.errors.participant_session_required"),
      )
      expect(
        Voice::ParticipantTracker.get_metadata(room.id, listener.id)[:hand_raised_at],
      ).to be_nil
    end

    it "requires authentication" do
      post "/voice/rooms/#{room.id}/request_to_speak.json"

      expect(response.status).to eq(403)
    end
  end

  describe "#withdraw_request_to_speak" do
    it "lowers the caller's raised hand and broadcasts the withdrawal plus the roster" do
      Voice::ParticipantTracker.raise_hand(room.id, listener.id)
      sign_in(listener)

      messages =
        MessageBus.track_publish(Voice.room_channel(room.id)) do
          delete "/voice/rooms/#{room.id}/request_to_speak.json",
                 params: {
                   participant_session_id: @listener_session_id,
                 }
        end

      expect(response.status).to eq(204)
      expect(
        Voice::ParticipantTracker.get_metadata(room.id, listener.id)[:hand_raised_at],
      ).to be_nil

      hand_message = messages.find { |message| message.data[:type] == "hand_raise" }
      expect(hand_message).to be_present
      expect(hand_message.data[:user_id]).to eq(listener.id)
      expect(hand_message.data[:raised]).to eq(false)
      expect(hand_message.data[:reason]).to eq("withdrawn")

      expect(messages.find { |message| message.data[:type] == "participants" }).to be_present
    end

    it "publishes nothing when the caller's hand is not raised" do
      sign_in(listener)

      messages =
        MessageBus.track_publish(Voice.room_channel(room.id)) do
          delete "/voice/rooms/#{room.id}/request_to_speak.json",
                 params: {
                   participant_session_id: @listener_session_id,
                 }
        end

      expect(response.status).to eq(204)
      expect(messages).to be_empty
    end

    it "lets the room creator dismiss another participant's raised hand" do
      Voice::ParticipantTracker.raise_hand(room.id, listener.id)
      sign_in(room_owner)

      messages =
        MessageBus.track_publish(Voice.room_channel(room.id)) do
          delete "/voice/rooms/#{room.id}/request_to_speak.json", params: { user_id: listener.id }
        end

      expect(response.status).to eq(204)
      expect(
        Voice::ParticipantTracker.get_metadata(room.id, listener.id)[:hand_raised_at],
      ).to be_nil

      hand_message = messages.find { |message| message.data[:type] == "hand_raise" }
      expect(hand_message).to be_present
      expect(hand_message.data[:user_id]).to eq(listener.id)
      expect(hand_message.data[:raised]).to eq(false)
      expect(hand_message.data[:reason]).to eq("dismissed")
    end

    it "lets site staff dismiss another participant's raised hand" do
      Voice::ParticipantTracker.raise_hand(room.id, listener.id)
      sign_in(staff)

      delete "/voice/rooms/#{room.id}/request_to_speak.json", params: { user_id: listener.id }

      expect(response.status).to eq(204)
      expect(
        Voice::ParticipantTracker.get_metadata(room.id, listener.id)[:hand_raised_at],
      ).to be_nil
    end

    it "returns 403 when a plain participant tries to dismiss someone else's hand" do
      Voice::ParticipantTracker.raise_hand(room.id, listener.id)
      Voice::ParticipantTracker.add(room.id, other_listener.id)
      sign_in(other_listener)

      delete "/voice/rooms/#{room.id}/request_to_speak.json", params: { user_id: listener.id }

      expect(response.status).to eq(403)
      expect(Voice::ParticipantTracker.get_metadata(room.id, listener.id)[:hand_raised_at]).to be_a(
        Float,
      )
    end
  end
end

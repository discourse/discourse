# frozen_string_literal: true

require "rails_helper"
require_relative "../../../db/migrate/20241107000000_create_voice_rooms"
require_relative "../../../db/migrate/20260630183841_add_chat_settings_to_voice_rooms"
require_relative "../../../db/migrate/20260709165411_add_livekit_enabled_to_voice_rooms"

RSpec.describe Voice::AdminRoomsController do
  before do
    ActiveRecord::Migration.suppress_messages do
      CreateVoiceRooms.new.change unless ActiveRecord::Base.connection.table_exists?(:voice_rooms)
      unless ActiveRecord::Base.connection.column_exists?(:voice_rooms, :chat_channel_id)
        AddChatSettingsToVoiceRooms.new.change
      end
      unless ActiveRecord::Base.connection.column_exists?(:voice_rooms, :livekit_enabled)
        AddLivekitEnabledToVoiceRooms.new.change
      end
    end
    Voice::Room.reset_column_information
    SiteSetting.voice_enabled = true
  end

  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:room) { Fabricate(:voice_room, creator: admin, public: true, name: "Test Room") }
  fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }

  describe "#index" do
    it "returns 403 for non-staff users" do
      sign_in(user)
      get "/admin/plugins/voice/rooms.json"
      expect(response.status).to eq(404)
    end

    it "returns rooms for admin users" do
      sign_in(admin)
      get "/admin/plugins/voice/rooms.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["rooms"]).to be_an(Array)
      expect(response.parsed_body["rooms"].first["name"]).to eq("Test Room")
    end
  end

  describe "#show" do
    it "returns 403 for non-staff users" do
      sign_in(user)
      get "/admin/plugins/voice/rooms/#{room.id}.json"
      expect(response.status).to eq(404)
    end

    it "returns room details for admin users" do
      sign_in(admin)
      get "/admin/plugins/voice/rooms/#{room.id}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["room"]["id"]).to eq(room.id)
      expect(response.parsed_body["room"]["name"]).to eq("Test Room")
      expect(response.parsed_body["room"]["creator"]).to be_present
    end

    it "includes the chat settings so the edit form can prefill them" do
      room.update!(chat_channel_id: channel.id, chat_idle_minutes: 2)
      sign_in(admin)

      get "/admin/plugins/voice/rooms/#{room.id}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["room"]["chat_channel_id"]).to eq(channel.id)
      expect(response.parsed_body["room"]["chat_idle_minutes"]).to eq(2)
    end

    it "returns 404 for non-existent room" do
      sign_in(admin)
      get "/admin/plugins/voice/rooms/99999.json"
      expect(response.status).to eq(404)
    end
  end

  describe "#create" do
    it "returns 403 for non-staff users" do
      sign_in(user)
      post "/admin/plugins/voice/rooms.json", params: { room: { name: "New Room" } }
      expect(response.status).to eq(404)
    end

    it "creates a room for admin users" do
      sign_in(admin)

      expect {
        post "/admin/plugins/voice/rooms.json",
             params: {
               room: {
                 name: "New Room",
                 description: "A test room",
                 public: true,
                 max_participants: 10,
               },
             }
      }.to change { Voice::Room.count }.by(1)

      expect(response.status).to eq(201)
      expect(response.parsed_body["room"]["name"]).to eq("New Room")
      expect(response.parsed_body["room"]["description"]).to eq("A test room")
      expect(response.parsed_body["room"]["public"]).to be(true)
      expect(response.parsed_body["room"]["max_participants"]).to eq(10)
    end

    it "creates a stage room when room_type is stage" do
      sign_in(admin)

      post "/admin/plugins/voice/rooms.json",
           params: {
             room: {
               name: "Town Hall",
               room_type: "stage",
             },
           }

      expect(response.status).to eq(201)
      expect(response.parsed_body["room"]["room_type"]).to eq("stage")
      expect(Voice::Room.find_by(name: "Town Hall").stage?).to eq(true)
    end

    it "rejects an unknown room_type" do
      sign_in(admin)

      expect {
        post "/admin/plugins/voice/rooms.json",
             params: {
               room: {
                 name: "Town Hall",
                 room_type: "arena",
               },
             }
      }.not_to change { Voice::Room.count }

      expect(response.status).to eq(400)
    end

    it "returns errors for invalid data" do
      sign_in(admin)

      post "/admin/plugins/voice/rooms.json", params: { room: { name: "" } }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to be_present
    end

    it "validates max_participants range" do
      sign_in(admin)

      post "/admin/plugins/voice/rooms.json",
           params: {
             room: {
               name: "New Room",
               max_participants: 100,
             },
           }

      expect(response.status).to eq(422)
    end
  end

  describe "#update" do
    it "returns 403 for non-staff users" do
      sign_in(user)
      put "/admin/plugins/voice/rooms/#{room.id}.json", params: { room: { name: "Updated" } }
      expect(response.status).to eq(404)
    end

    it "updates a room for admin users" do
      sign_in(admin)

      put "/admin/plugins/voice/rooms/#{room.id}.json",
          params: {
            room: {
              name: "Updated Room",
              description: "Updated description",
            },
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["room"]["name"]).to eq("Updated Room")
      expect(response.parsed_body["room"]["description"]).to eq("Updated description")

      room.reload
      expect(room.name).to eq("Updated Room")
    end

    it "accepts a slug change" do
      sign_in(admin)

      put "/admin/plugins/voice/rooms/#{room.id}.json", params: { room: { slug: "New Hangout" } }

      expect(response.status).to eq(200)
      expect(room.reload.slug).to eq("new-hangout")
    end

    it "persists and serializes room_type so the edit form can prefill it" do
      sign_in(admin)

      put "/admin/plugins/voice/rooms/#{room.id}.json", params: { room: { room_type: "stage" } }

      expect(response.status).to eq(200)
      expect(response.parsed_body["room"]["room_type"]).to eq("stage")
      expect(room.reload.stage?).to eq(true)

      get "/admin/plugins/voice/rooms/#{room.id}.json"

      expect(response.parsed_body["room"]["room_type"]).to eq("stage")
    end

    it "keeps a stage room's type when an update rejects an unknown room_type" do
      sign_in(admin)
      room.update!(room_type: Voice::Room::ROOM_TYPE_STAGE)

      put "/admin/plugins/voice/rooms/#{room.id}.json", params: { room: { room_type: "arena" } }

      expect(response.status).to eq(400)
      expect(room.reload.stage?).to eq(true)
    end

    it "persists and serializes livekit_enabled" do
      sign_in(admin)

      put "/admin/plugins/voice/rooms/#{room.id}.json", params: { room: { livekit_enabled: true } }

      expect(response.status).to eq(200)
      expect(response.parsed_body["room"]["livekit_enabled"]).to eq(true)
      expect(room.reload.livekit_enabled).to eq(true)
    end

    it "persists the chat settings fields" do
      sign_in(admin)

      put "/admin/plugins/voice/rooms/#{room.id}.json",
          params: {
            room: {
              chat_channel_id: channel.id,
              chat_idle_minutes: 2,
            },
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["room"]["chat_channel_id"]).to eq(channel.id)
      expect(response.parsed_body["room"]["chat_idle_minutes"]).to eq(2)

      room.reload
      expect(room.chat_channel_id).to eq(channel.id)
      expect(room.chat_idle_minutes).to eq(2)
    end

    it "returns 404 for non-existent room" do
      sign_in(admin)
      put "/admin/plugins/voice/rooms/99999.json", params: { room: { name: "Updated" } }
      expect(response.status).to eq(404)
    end

    it "returns errors for invalid data" do
      sign_in(admin)

      put "/admin/plugins/voice/rooms/#{room.id}.json", params: { room: { name: "" } }

      expect(response.status).to eq(422)
    end
  end

  describe "#destroy" do
    it "returns 403 for non-staff users" do
      sign_in(user)
      delete "/admin/plugins/voice/rooms/#{room.id}.json"
      expect(response.status).to eq(404)
    end

    it "deletes a room for admin users" do
      sign_in(admin)

      expect { delete "/admin/plugins/voice/rooms/#{room.id}.json" }.to change {
        Voice::Room.count
      }.by(-1)

      expect(response.status).to eq(204)
    end

    it "deletes a room that has session history and keeps the sessions" do
      session = Fabricate(:voice_session, user: user, room: room)
      sign_in(admin)

      expect { delete "/admin/plugins/voice/rooms/#{room.id}.json" }.to change {
        Voice::Room.count
      }.by(-1)

      expect(response.status).to eq(204)
      expect(session.reload.room_id).to eq(room.id)
    end

    it "returns 404 for non-existent room" do
      sign_in(admin)
      delete "/admin/plugins/voice/rooms/99999.json"
      expect(response.status).to eq(404)
    end

    it "deletes a livekit-pinned room from the SFU and clears the pin" do
      sign_in(admin)
      SiteSetting.voice_livekit_url = "wss://livekit.example.com"
      SiteSetting.voice_livekit_api_key = "lk_api_key"
      SiteSetting.voice_livekit_api_secret = "lk_api_secret"
      Voice::ParticipantTracker.pin_transport!(room.id, "livekit")
      stub = stub_request(:post, "https://livekit.example.com/twirp/livekit.RoomService/DeleteRoom")

      delete "/admin/plugins/voice/rooms/#{room.id}.json"

      expect(response.status).to eq(204)
      expect(stub).to have_been_requested
      expect(Voice::ParticipantTracker.pinned_transport(room.id)).to be_nil
    end
  end

  describe "#end_call" do
    fab!(:participant, :user)
    fab!(:other_participant, :user)

    before do
      Voice::ParticipantTracker.add(room.id, participant.id)
      Voice::ParticipantTracker.add(room.id, other_participant.id)
    end

    after { Voice::ParticipantTracker.clear(room.id) }

    it "returns 404 for non-staff users" do
      sign_in(user)
      post "/admin/plugins/voice/rooms/#{room.id}/end_call.json"
      expect(response.status).to eq(404)
    end

    it "returns 404 for non-existent room" do
      sign_in(admin)
      post "/admin/plugins/voice/rooms/99999/end_call.json"
      expect(response.status).to eq(404)
    end

    it "kicks every participant and clears the transport pin" do
      sign_in(admin)
      Voice::ParticipantTracker.pin_transport!(room.id, "mesh")

      messages =
        MessageBus.track_publish(Voice.room_channel(room.id)) do
          post "/admin/plugins/voice/rooms/#{room.id}/end_call.json"
        end

      expect(response.status).to eq(204)
      kicks = messages.select { |message| message.data[:type] == "kicked" }
      expect(kicks.map(&:user_ids)).to contain_exactly([participant.id], [other_participant.id])
      expect(Voice::ParticipantTracker.pinned_transport(room.id)).to be_nil
    end

    it "also deletes the SFU room when the call is pinned to livekit" do
      sign_in(admin)
      SiteSetting.voice_livekit_url = "wss://livekit.example.com"
      SiteSetting.voice_livekit_api_key = "lk_api_key"
      SiteSetting.voice_livekit_api_secret = "lk_api_secret"
      Voice::ParticipantTracker.pin_transport!(room.id, "livekit")
      stub =
        stub_request(
          :post,
          "https://livekit.example.com/twirp/livekit.RoomService/DeleteRoom",
        ).with(body: { room: Voice::Livekit.room_name(room) }.to_json)

      post "/admin/plugins/voice/rooms/#{room.id}/end_call.json"

      expect(response.status).to eq(204)
      expect(stub).to have_been_requested
      expect(Voice::ParticipantTracker.pinned_transport(room.id)).to be_nil
    end

    it "still ends the call when LiveKit is down" do
      sign_in(admin)
      SiteSetting.voice_livekit_url = "wss://livekit.example.com"
      SiteSetting.voice_livekit_api_key = "lk_api_key"
      SiteSetting.voice_livekit_api_secret = "lk_api_secret"
      Voice::ParticipantTracker.pin_transport!(room.id, "livekit")
      stub_request(
        :post,
        "https://livekit.example.com/twirp/livekit.RoomService/DeleteRoom",
      ).to_timeout

      messages =
        MessageBus.track_publish(Voice.room_channel(room.id)) do
          post "/admin/plugins/voice/rooms/#{room.id}/end_call.json"
        end

      expect(response.status).to eq(204)
      expect(messages.count { |message| message.data[:type] == "kicked" }).to eq(2)
      expect(Voice::ParticipantTracker.pinned_transport(room.id)).to be_nil
    end
  end
end

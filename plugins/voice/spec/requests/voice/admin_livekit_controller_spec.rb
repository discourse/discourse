# frozen_string_literal: true

require "rails_helper"
require_relative "../../../db/migrate/20241107000000_create_voice_rooms"
require_relative "../../../db/migrate/20260305162426_add_room_type_to_voice_rooms"
require_relative "../../../db/migrate/20260612135211_add_video_enabled_to_voice_rooms"
require_relative "../../../db/migrate/20260630183841_add_chat_settings_to_voice_rooms"
require_relative "../../../db/migrate/20260709165411_add_livekit_enabled_to_voice_rooms"

RSpec.describe Voice::AdminLivekitController do
  before do
    ActiveRecord::Migration.suppress_messages do
      CreateVoiceRooms.new.change unless ActiveRecord::Base.connection.table_exists?(:voice_rooms)
      unless ActiveRecord::Base.connection.column_exists?(:voice_rooms, :room_type)
        AddRoomTypeToVoiceRooms.new.change
      end
      unless ActiveRecord::Base.connection.column_exists?(:voice_rooms, :video_enabled)
        AddVideoEnabledToVoiceRooms.new.change
      end
      unless ActiveRecord::Base.connection.column_exists?(:voice_rooms, :chat_channel_id)
        AddChatSettingsToVoiceRooms.new.change
      end
      unless ActiveRecord::Base.connection.column_exists?(:voice_rooms, :livekit_enabled)
        AddLivekitEnabledToVoiceRooms.new.change
      end
    end
    Voice::Room.reset_column_information
  end

  fab!(:admin)
  fab!(:user)
  fab!(:other_user, :user)
  fab!(:ghost_user, :user)
  fab!(:room) { Fabricate(:voice_room, public: true) }

  before { SiteSetting.voice_enabled = true }

  after do
    Voice::ParticipantTracker.clear(room.id)
    Discourse.redis.del(Voice::Livekit::HealthCheck::LAST_PROBE_KEY)
    Discourse.redis.del(Voice::Livekit::LAST_WEBHOOK_KEY)
  end

  def configure_livekit!
    SiteSetting.voice_livekit_url = "wss://livekit.example.com"
    SiteSetting.voice_livekit_api_key = "lk_api_key"
    SiteSetting.voice_livekit_api_secret = "lk_api_secret"
  end

  def list_rooms_stub
    stub_request(:post, "https://livekit.example.com/twirp/livekit.RoomService/ListRooms")
  end

  def list_participants_stub
    stub_request(:post, "https://livekit.example.com/twirp/livekit.RoomService/ListParticipants")
  end

  def get_status
    get "/admin/plugins/voice/livekit/status.json"
  end

  def post_probe
    post "/admin/plugins/voice/livekit/probe.json"
  end

  describe "access control" do
    it "is hidden from anonymous users" do
      get_status
      expect(response.status).to eq(404)
    end

    it "is hidden from regular users" do
      sign_in(user)
      get_status
      expect(response.status).to eq(404)
    end

    it "is available to admins" do
      sign_in(admin)
      get_status
      expect(response.status).to eq(200)
    end

    it "includes the site's webhook endpoint for the config snippet" do
      sign_in(admin)
      get_status
      expect(response.parsed_body["webhook_url"]).to eq(
        "#{Discourse.base_url}/voice/livekit/webhook",
      )
    end
  end

  describe "when LiveKit is not configured" do
    before { sign_in(admin) }

    it "reports the missing settings without probing anything" do
      probe_stub = stub_request(:post, %r{\Ahttps://})

      get_status

      body = response.parsed_body
      expect(body["configured"]).to eq(false)
      expect(body["settings"]).to eq(
        "url_present" => false,
        "api_key_present" => false,
        "api_secret_present" => false,
        "policy" => "disabled",
      )
      expect(body["rooms"]).to eq([])
      expect(body).not_to have_key("token_check")
      expect(body).not_to have_key("server_check")
      expect(probe_stub).not_to have_been_requested
    end

    it "reports which settings are present on a half-configured install" do
      SiteSetting.voice_livekit_url = "wss://livekit.example.com"

      get_status

      settings = response.parsed_body["settings"]
      expect(settings["url_present"]).to eq(true)
      expect(settings["api_key_present"]).to eq(false)
      expect(settings["api_secret_present"]).to eq(false)
    end
  end

  describe "when LiveKit is configured" do
    before do
      sign_in(admin)
      configure_livekit!
    end

    it "returns a passing token check and a timed server probe" do
      list_rooms_stub.to_return(
        status: 200,
        body: { rooms: [{ name: "default-r1" }, { name: "default-r2" }] }.to_json,
      )

      get_status

      body = response.parsed_body
      expect(body["configured"]).to eq(true)
      expect(body["token_check"]).to eq("ok" => true)
      expect(body["server_check"]["ok"]).to eq(true)
      expect(body["server_check"]["latency_ms"]).to be_a(Integer)
      expect(body["server_check"]["room_count"]).to eq(2)
    end

    it "probes with a roomList-granted token" do
      list_rooms_stub.to_return(status: 200, body: { rooms: [] }.to_json)

      get_status

      expect(
        a_request(
          :post,
          "https://livekit.example.com/twirp/livekit.RoomService/ListRooms",
        ).with do |req|
          token = req.headers["Authorization"].delete_prefix("Bearer ")
          claims =
            JWT.decode(token, SiteSetting.voice_livekit_api_secret, true, algorithm: "HS256").first
          claims["iss"] == "lk_api_key" && claims["video"] == { "roomList" => true }
        end,
      ).to have_been_made.once
    end

    it "surfaces the server error string when the probe fails" do
      list_rooms_stub.to_return(status: 401, body: "invalid authorization token")

      get_status

      server_check = response.parsed_body["server_check"]
      expect(server_check["ok"]).to eq(false)
      expect(server_check["error"]).to include("HTTP 401")
    end

    it "surfaces connection errors as strings, never raising" do
      list_rooms_stub.to_timeout

      get_status

      expect(response.status).to eq(200)
      server_check = response.parsed_body["server_check"]
      expect(server_check["ok"]).to eq(false)
      expect(server_check["error"]).to be_present
    end

    it "surfaces the stored probe result and the webhook freshness marker" do
      list_rooms_stub.to_return(status: 200, body: { rooms: [] }.to_json)
      freeze_time
      Voice::Livekit.touch_last_webhook!
      Jobs::VoiceLivekitProbe.new.execute({})

      get_status

      body = response.parsed_body
      # iso8601 truncates fractional seconds, so compare whole seconds
      expect(Time.parse(body["last_webhook_at"]).to_i).to eq(Time.now.to_i)
      expect(body["last_probe"]["ok"]).to eq(true)
      expect(body["last_probe"]["checked_at"]).to eq(Time.now.utc.iso8601)
    end

    it "stores a fresh connectivity result when an admin refreshes the probe" do
      list_rooms_stub.to_return(status: 200, body: { rooms: [] }.to_json)
      freeze_time

      post_probe

      expect(response.status).to eq(200)
      probe = response.parsed_body["last_probe"]
      expect(probe["ok"]).to eq(true)
      expect(probe["checked_at"]).to eq(Time.now.utc.iso8601)
      expect(probe["token"]).to eq("ok" => true)
      expect(probe["server"]["latency_ms"]).to be_a(Integer)
      expect(probe["server"]["room_count"]).to eq(0)
      expect(Voice::Livekit::HealthCheck.last_probe[:ok]).to eq(true)
    end

    describe "pinned livekit rooms" do
      before do
        Voice::ParticipantTracker.pin_transport!(room.id, "livekit")
        Voice::ParticipantTracker.add(room.id, user.id)
        Voice::ParticipantTracker.add(room.id, other_user.id)
        list_rooms_stub.to_return(status: 200, body: { rooms: [] }.to_json)
      end

      it "diffs Redis presence against the participants LiveKit reports" do
        # `other_user` is in the roster but unknown to LiveKit (the classic
        # "connects but no media" victim); `ghost_user` is connected to the
        # SFU but fell out of the roster; non-numeric identities (egress,
        # other tools) are ignored.
        list_participants_stub.to_return(
          status: 200,
          body: {
            participants: [
              { identity: user.id.to_s },
              { identity: ghost_user.id.to_s },
              { identity: "recorder-1" },
            ],
          }.to_json,
        )

        get_status

        rooms = response.parsed_body["rooms"]
        expect(rooms.size).to eq(1)
        room_status = rooms.first
        expect(room_status["room_id"]).to eq(room.id)
        expect(room_status["name"]).to eq(room.name)
        expect(room_status["presence_user_ids"]).to eq([user.id, other_user.id].sort)
        expect(room_status["livekit_user_ids"]).to eq([user.id, ghost_user.id].sort)
        expect(room_status["missing_on_livekit"]).to eq([other_user.id])
        expect(room_status["missing_in_presence"]).to eq([ghost_user.id])

        usernames = response.parsed_body["usernames"]
        expect(usernames[user.id.to_s]).to eq(user.username)
        expect(usernames[other_user.id.to_s]).to eq(other_user.username)
        expect(usernames[ghost_user.id.to_s]).to eq(ghost_user.username)
      end

      it "reports a per-room error when listing participants fails" do
        list_participants_stub.to_return(status: 500, body: "internal error")

        get_status

        room_status = response.parsed_body["rooms"].first
        expect(room_status["error"]).to include("HTTP 500")
        expect(room_status).not_to have_key("livekit_user_ids")
        expect(room_status["presence_user_ids"]).to eq([user.id, other_user.id].sort)
      end

      it "skips per-room probes when the server is already unreachable" do
        list_rooms_stub.to_timeout
        participants_stub = list_participants_stub

        get_status

        room_status = response.parsed_body["rooms"].first
        expect(room_status["presence_user_ids"]).to eq([user.id, other_user.id].sort)
        expect(room_status).not_to have_key("livekit_user_ids")
        expect(room_status).not_to have_key("error")
        expect(participants_stub).not_to have_been_requested
      end

      it "ignores rooms pinned to mesh" do
        Voice::ParticipantTracker.clear_transport_pin(room.id)
        Voice::ParticipantTracker.pin_transport!(room.id, "mesh")

        get_status

        expect(response.parsed_body["rooms"]).to eq([])
      end
    end

    it "never leaks the API secret or key in the status payload or the site serializer" do
      list_rooms_stub.to_return(status: 401, body: "invalid authorization token")
      list_participants_stub.to_return(status: 401, body: "invalid authorization token")
      Voice::ParticipantTracker.pin_transport!(room.id, "livekit")
      Voice::ParticipantTracker.add(room.id, user.id)
      Jobs::VoiceLivekitProbe.new.execute({})

      get_status
      expect(response.status).to eq(200)
      expect(response.body).not_to include("lk_api_secret")
      expect(response.body).not_to include("lk_api_key")

      get "/site.json"
      expect(response.status).to eq(200)
      expect(response.body).not_to include("lk_api_secret")
    end
  end
end

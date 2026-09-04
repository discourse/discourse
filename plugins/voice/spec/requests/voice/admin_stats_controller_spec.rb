# frozen_string_literal: true

RSpec.describe Voice::AdminStatsController do
  fab!(:admin)
  fab!(:user)
  fab!(:room) { Fabricate(:voice_room, creator: admin, name: "Watercooler") }
  fab!(:room_2, :voice_room) { Fabricate(:voice_room, creator: admin, name: "Lounge") }

  before { SiteSetting.voice_enabled = true }

  describe "#overview" do
    it "rejects non-admin users" do
      sign_in(user)
      get "/admin/plugins/voice/stats/overview.json"
      expect(response.status).to eq(404)
    end

    it "returns zeroes when there are no sessions" do
      sign_in(admin)
      get "/admin/plugins/voice/stats/overview.json", params: { period: "weekly" }

      expect(response.status).to eq(200)
      body = response.parsed_body
      expect(body["total_sessions"]).to eq(0)
      expect(body["unique_users"]).to eq(0)
      expect(body["avg_duration"]).to eq(0)
    end

    it "returns aggregated stats for sessions in the period" do
      Fabricate(
        :voice_session,
        user: admin,
        room: room,
        joined_at: 2.hours.ago,
        left_at: 1.hour.ago,
      )
      Fabricate(:voice_session, user: user, room: room, joined_at: 3.hours.ago, left_at: 1.hour.ago)

      sign_in(admin)
      get "/admin/plugins/voice/stats/overview.json", params: { period: "weekly" }

      expect(response.status).to eq(200)
      body = response.parsed_body
      expect(body["total_sessions"]).to eq(2)
      expect(body["unique_users"]).to eq(2)
      expect(body["avg_duration"]).to be > 0
    end

    it "excludes sessions outside the period" do
      Fabricate(
        :voice_session,
        user: admin,
        room: room,
        joined_at: 10.days.ago,
        left_at: 10.days.ago + 1.hour,
      )

      sign_in(admin)
      get "/admin/plugins/voice/stats/overview.json", params: { period: "weekly" }

      expect(response.parsed_body["total_sessions"]).to eq(0)
    end

    it "defaults to 7 days for invalid period" do
      Fabricate(
        :voice_session,
        user: admin,
        room: room,
        joined_at: 2.days.ago,
        left_at: 2.days.ago + 30.minutes,
      )

      sign_in(admin)
      get "/admin/plugins/voice/stats/overview.json", params: { period: "bogus" }

      expect(response.status).to eq(200)
      expect(response.parsed_body["total_sessions"]).to eq(1)
    end

    it "supports custom date ranges" do
      Fabricate(
        :voice_session,
        user: admin,
        room: room,
        joined_at: 20.days.ago,
        left_at: 20.days.ago + 1.hour,
      )
      Fabricate(
        :voice_session,
        user: user,
        room: room,
        joined_at: 2.days.ago,
        left_at: 2.days.ago + 30.minutes,
      )

      sign_in(admin)
      get "/admin/plugins/voice/stats/overview.json",
          params: {
            period: "custom",
            start_date: 25.days.ago.to_date.to_s,
            end_date: 15.days.ago.to_date.to_s,
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["total_sessions"]).to eq(1)
      expect(response.parsed_body["unique_users"]).to eq(1)
    end
  end

  describe "#rooms" do
    it "rejects non-admin users" do
      sign_in(user)
      get "/admin/plugins/voice/stats/rooms.json"
      expect(response.status).to eq(404)
    end

    it "returns rooms ranked by total time" do
      Fabricate(
        :voice_session,
        user: admin,
        room: room,
        joined_at: 3.hours.ago,
        left_at: 1.hour.ago,
      )
      Fabricate(
        :voice_session,
        user: user,
        room: room_2,
        joined_at: 2.hours.ago,
        left_at: 1.5.hours.ago,
      )

      sign_in(admin)
      get "/admin/plugins/voice/stats/rooms.json", params: { period: "weekly" }

      expect(response.status).to eq(200)
      rooms = response.parsed_body["rooms"]
      expect(rooms.length).to eq(2)
      expect(rooms.first["room_name"]).to eq("Watercooler")
      expect(rooms.first["unique_users"]).to eq(1)
      expect(rooms.first["total_seconds"]).to be > 0
    end

    it "keeps sessions of deleted rooms in the ranking with a null name" do
      doomed_room = Fabricate(:voice_room, creator: admin, name: "Doomed")
      Fabricate(
        :voice_session,
        user: user,
        room: doomed_room,
        joined_at: 2.hours.ago,
        left_at: 1.hour.ago,
      )
      doomed_room.destroy!

      sign_in(admin)
      get "/admin/plugins/voice/stats/rooms.json", params: { period: "weekly" }

      expect(response.status).to eq(200)
      deleted_row = response.parsed_body["rooms"].find { |r| r["room_id"] == doomed_room.id }
      expect(deleted_row).to be_present
      expect(deleted_row["room_name"]).to be_nil
      expect(deleted_row["unique_users"]).to eq(1)
    end
  end

  describe "#users" do
    it "rejects non-admin users" do
      sign_in(user)
      get "/admin/plugins/voice/stats/users.json"
      expect(response.status).to eq(404)
    end

    it "returns users ranked by total time" do
      Fabricate(
        :voice_session,
        user: admin,
        room: room,
        joined_at: 4.hours.ago,
        left_at: 1.hour.ago,
      )
      Fabricate(
        :voice_session,
        user: user,
        room: room,
        joined_at: 2.hours.ago,
        left_at: 1.5.hours.ago,
      )

      sign_in(admin)
      get "/admin/plugins/voice/stats/users.json", params: { period: "weekly" }

      expect(response.status).to eq(200)
      users = response.parsed_body["users"]
      expect(users.length).to eq(2)
      expect(users.first["username"]).to eq(admin.username)
      expect(users.first["session_count"]).to eq(1)
      expect(users.first["total_seconds"]).to be > 0
      expect(users.first["avatar_template"]).to be_present
    end

    it "keeps sessions of deleted users in the ranking with a null username" do
      doomed_user = Fabricate(:user)
      Fabricate(
        :voice_session,
        user: doomed_user,
        room: room,
        joined_at: 2.hours.ago,
        left_at: 1.hour.ago,
      )
      UserDestroyer.new(admin).destroy(doomed_user)

      sign_in(admin)
      get "/admin/plugins/voice/stats/users.json", params: { period: "weekly" }

      expect(response.status).to eq(200)
      deleted_row = response.parsed_body["users"].find { |u| u["user_id"] == doomed_user.id }
      expect(deleted_row).to be_present
      expect(deleted_row["username"]).to be_nil
      expect(deleted_row["session_count"]).to eq(1)
    end
  end
end

# frozen_string_literal: true

require "rails_helper"
require_relative "../../../db/migrate/20241107000000_create_voice_rooms"
require_relative "../../../db/migrate/20260612135211_add_video_enabled_to_voice_rooms"

RSpec.describe Voice::PageController do
  before do
    ActiveRecord::Migration.suppress_messages do
      CreateVoiceRooms.new.change unless ActiveRecord::Base.connection.table_exists?(:voice_rooms)
      unless ActiveRecord::Base.connection.column_exists?(:voice_rooms, :video_enabled)
        AddVideoEnabledToVoiceRooms.new.change
        Voice::Room.reset_column_information
      end
    end
    SiteSetting.voice_enabled = true
    SiteSetting.voice_allowed_groups =
      "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"
  end

  fab!(:staff, :admin)
  fab!(:user)
  fab!(:room) { Fabricate(:voice_room, creator: staff, public: true) }

  describe "#show" do
    it "renders the app shell for a visible room" do
      sign_in(user)

      get "/voice/r/#{room.slug}"

      expect(response.status).to eq(200)
      expect(response.body).to include("discourse")
    end

    it "renders the app shell for an invite link carrying the inviter's username" do
      sign_in(user)

      get "/voice/r/#{room.slug}/invited-by/#{staff.username_lower}"

      expect(response.status).to eq(200)
    end

    it "returns 404 for an unknown slug" do
      sign_in(user)

      get "/voice/r/not-a-room"

      expect(response.status).to eq(404)
    end

    it "rejects users who cannot see the room" do
      private_room = Fabricate(:voice_room, creator: staff, public: false)
      sign_in(user)

      get "/voice/r/#{private_room.slug}"

      expect(response.status).to eq(403)
    end

    it "renders for anonymous visitors when anonymous visitors are admitted" do
      get "/voice/r/#{room.slug}"

      expect(response.status).to eq(200)
    end

    it "rejects anonymous visitors when access is restricted to a group" do
      SiteSetting.voice_allowed_groups = "#{Group::AUTO_GROUPS[:trust_level_2]}"

      get "/voice/r/#{room.slug}"

      expect(response.status).to eq(403)
    end
  end
end

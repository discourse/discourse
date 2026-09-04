# frozen_string_literal: true

require "rails_helper"
require_relative "../../../db/migrate/20241107000000_create_voice_rooms"
require_relative "../../../db/migrate/20260305162426_add_room_type_to_voice_rooms"
require_relative "../../../db/migrate/20260612135211_add_video_enabled_to_voice_rooms"
require_relative "../../../db/migrate/20260630183841_add_chat_settings_to_voice_rooms"
require_relative "../../../db/migrate/20260728201053_add_max_quality_profile_to_voice_rooms"

RSpec.describe Voice::Room do
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
      unless ActiveRecord::Base.connection.column_exists?(:voice_rooms, :max_quality_profile)
        AddMaxQualityProfileToVoiceRooms.new.change
      end
    end
    Voice::Room.reset_column_information
  end

  fab!(:room, :voice_room)

  describe ".visible_to" do
    def visible_room_ids(guardian, room_ids)
      described_class.visible_to(guardian).where(id: room_ids).pluck(:id)
    end

    it "matches room visibility for public access, members, creators, and staff" do
      SiteSetting.voice_enabled = true
      SiteSetting.voice_allowed_groups =
        "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"
      owner = Fabricate(:user)
      member = Fabricate(:user)
      staff = Fabricate(:admin)
      public_room = Fabricate(:voice_room, creator: owner, public: true)
      private_room = Fabricate(:voice_room, creator: owner, public: false)
      private_room.room_memberships.create!(user: member)
      creator_only_room = Fabricate(:voice_room, creator: owner, public: false)
      creator_only_room.room_memberships.delete_all
      ephemeral_room = Fabricate(:voice_ephemeral_room, creator: owner, public: true)
      room_ids = [public_room, private_room, creator_only_room, ephemeral_room].map(&:id)

      expect(visible_room_ids(Guardian.new(nil), room_ids)).to contain_exactly(public_room.id)
      expect(visible_room_ids(member.guardian, room_ids)).to contain_exactly(
        public_room.id,
        private_room.id,
      )
      expect(visible_room_ids(owner.guardian, room_ids)).to contain_exactly(
        public_room.id,
        private_room.id,
        creator_only_room.id,
      )
      expect(visible_room_ids(staff.guardian, room_ids)).to contain_exactly(
        public_room.id,
        private_room.id,
        creator_only_room.id,
      )

      SiteSetting.voice_allowed_groups = Group::AUTO_GROUPS[:anonymous_users].to_s
      expect(visible_room_ids(member.guardian, room_ids)).to contain_exactly(public_room.id)
      expect(visible_room_ids(staff.guardian, room_ids)).to contain_exactly(public_room.id)

      SiteSetting.voice_enabled = false
      expect(visible_room_ids(Guardian.new(nil), room_ids)).to be_empty
    end
  end

  describe "slug generation" do
    it "appends a random suffix for ephemeral rooms so generic names never collide" do
      persistent = Fabricate(:voice_room, name: "Call")
      ephemeral = Fabricate(:voice_ephemeral_room, name: "Call")

      expect(persistent.slug).to eq("call")
      expect(ephemeral.slug).to match(/\Acall-\h{8}\z/)
    end

    it "normalizes and keeps a user-provided slug" do
      custom = Fabricate(:voice_room, name: "Game Night", slug: "Friday Hangout")

      expect(custom.slug).to eq("friday-hangout")
    end

    it "rejects a provided slug that normalizes to nothing" do
      custom = Fabricate.build(:voice_room, name: "Game Night", slug: "!!!")

      expect(custom).not_to be_valid
      expect(custom.errors[:slug]).to be_present
    end

    it "keeps the existing slug when the room is renamed" do
      room.update!(name: "Renamed room")

      expect(room.reload.slug).not_to eq("renamed-room")
    end

    it "regenerates the slug from the name when it is cleared" do
      room.update!(name: "Fresh name", slug: "")

      expect(room.reload.slug).to eq("fresh-name")
    end
  end

  describe "membership predicates" do
    it "reuses loaded memberships" do
      creator = room.creator
      room.room_memberships.load

      queries =
        track_sql_queries do
          expect(room.member?(creator)).to eq(true)
          expect(room.moderator?(creator)).to eq(true)
          expect(room.member_ids).to contain_exactly(room.creator_id)
          expect(room.moderator_ids).to contain_exactly(room.creator_id)
        end

      expect(queries).to be_empty
    end
  end

  describe "chat_idle_minutes validation" do
    it "rejects a value below the 2 minute floor" do
      room.chat_idle_minutes = 1
      expect(room).not_to be_valid
      expect(room.errors[:chat_idle_minutes]).to be_present
    end

    it "accepts the 2 minute floor" do
      room.chat_idle_minutes = 2
      expect(room).to be_valid
    end

    it "rejects a value above the 1440 minute (24h) ceiling" do
      room.chat_idle_minutes = 1441
      expect(room).not_to be_valid
    end

    it "defaults to 15 minutes" do
      expect(described_class.new.chat_idle_minutes).to eq(15)
    end
  end

  describe "max_quality_profile validation" do
    it "accepts nil, meaning no room-level cap" do
      room.max_quality_profile = nil
      expect(room).to be_valid
    end

    it "accepts every known profile" do
      Voice::Room::QUALITY_PROFILES.each_value do |profile|
        room.max_quality_profile = profile
        expect(room).to be_valid
      end
    end

    it "rejects unknown values" do
      room.max_quality_profile = 42
      expect(room).not_to be_valid
      expect(room.errors[:max_quality_profile]).to be_present
    end
  end

  describe "#max_quality_profile_name" do
    it "maps the stored integer back to its name and nil to nil" do
      expect(described_class.new(max_quality_profile: 1).max_quality_profile_name).to eq("high")
      expect(described_class.new.max_quality_profile_name).to be_nil
    end
  end

  describe "#chat_idle_seconds" do
    it "floors to 2 minutes even if a lower value slipped through" do
      room.update_column(:chat_idle_minutes, 0)
      expect(room.reload.chat_idle_seconds).to eq(2 * 60)
    end

    it "converts minutes to seconds" do
      room.update!(chat_idle_minutes: 5)
      expect(room.chat_idle_seconds).to eq(5 * 60)
    end
  end

  describe "chat_channel_id validation" do
    fab!(:threaded_channel) { Fabricate(:chat_channel, threading_enabled: true) }
    fab!(:unthreaded_channel) { Fabricate(:chat_channel, threading_enabled: false) }

    it "allows linking a channel that already has threading enabled" do
      room.chat_channel_id = threaded_channel.id
      expect(room).to be_valid
    end

    it "rejects linking a channel without threading enabled" do
      room.chat_channel_id = unthreaded_channel.id
      expect(room).not_to be_valid
      expect(room.errors[:chat_channel_id]).to be_present
    end

    it "rejects linking a channel id that doesn't exist" do
      room.chat_channel_id = unthreaded_channel.id + 100_000
      expect(room).not_to be_valid
      expect(room.errors[:chat_channel_id]).to be_present
    end

    it "allows clearing the channel back to none" do
      room.update!(chat_channel_id: threaded_channel.id)
      room.chat_channel_id = nil
      expect(room).to be_valid
    end

    it "does not re-validate on an unrelated save once linked, even if the channel's threading is later disabled" do
      room.update!(chat_channel_id: threaded_channel.id)
      threaded_channel.update!(threading_enabled: false)

      room.name = "Renamed"
      expect(room).to be_valid
    end
  end
end

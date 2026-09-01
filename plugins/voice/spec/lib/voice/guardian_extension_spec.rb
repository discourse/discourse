# frozen_string_literal: true

require "rails_helper"
require_relative "../../../db/migrate/20241107000000_create_voice_rooms"
require_relative "../../../db/migrate/20260305162426_add_room_type_to_voice_rooms"
require_relative "../../../db/migrate/20260612135211_add_video_enabled_to_voice_rooms"

RSpec.describe Voice::GuardianExtension do
  before do
    ActiveRecord::Migration.suppress_messages do
      CreateVoiceRooms.new.change unless ActiveRecord::Base.connection.table_exists?(:voice_rooms)
      unless ActiveRecord::Base.connection.column_exists?(:voice_rooms, :room_type)
        AddRoomTypeToVoiceRooms.new.change
        Voice::Room.reset_column_information
      end
      unless ActiveRecord::Base.connection.column_exists?(:voice_rooms, :video_enabled)
        AddVideoEnabledToVoiceRooms.new.change
        Voice::Room.reset_column_information
      end
    end
  end

  fab!(:staff, :admin)
  fab!(:creator) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:room_moderator) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:room_speaker) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:member) { Fabricate(:user, trust_level: TrustLevel[2]) }

  # In voice_create_room_allowed_groups but with no tie to the private room:
  # the room-creation permission must not leak into other people's rooms.
  fab!(:outsider) { Fabricate(:user, trust_level: TrustLevel[2]) }

  fab!(:low_trust_user) { Fabricate(:user, trust_level: TrustLevel[0]) }
  fab!(:public_room) { Fabricate(:voice_room, creator: staff, public: true) }
  fab!(:private_room) { Fabricate(:voice_room, creator: creator, public: false) }

  fab!(:moderator_membership) do
    private_room.room_memberships.create!(
      user: room_moderator,
      role: Voice::RoomMembership::ROLE_MODERATOR,
    )
  end

  fab!(:speaker_membership) do
    private_room.room_memberships.create!(
      user: room_speaker,
      role: Voice::RoomMembership::ROLE_SPEAKER,
    )
  end

  fab!(:participant_membership) do
    private_room.room_memberships.create!(
      user: member,
      role: Voice::RoomMembership::ROLE_PARTICIPANT,
    )
  end

  let(:anonymous_guardian) { Guardian.new(nil) }

  before do
    SiteSetting.voice_enabled = true
    SiteSetting.voice_allowed_groups =
      "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"
    SiteSetting.voice_create_room_allowed_groups = "#{Group::AUTO_GROUPS[:trust_level_2]}"
  end

  describe "#voice_public_access?" do
    it "is true when anonymous visitors are admitted on a public site" do
      expect(anonymous_guardian.voice_public_access?).to eq(true)
    end

    it "is false on login-required sites even when anonymous visitors are admitted" do
      SiteSetting.login_required = true

      expect(anonymous_guardian.voice_public_access?).to eq(false)
    end

    it "is true when access is open to the anonymous_users pseudogroup" do
      SiteSetting.voice_allowed_groups = "#{Group::AUTO_GROUPS[:anonymous_users]}"

      expect(anonymous_guardian.voice_public_access?).to eq(true)
    end

    it "is false when access is limited to logged-in users" do
      SiteSetting.voice_allowed_groups = "#{Group::AUTO_GROUPS[:logged_in_users]}"

      expect(anonymous_guardian.voice_public_access?).to eq(false)
    end
  end

  describe "#can_create_voice_room?" do
    it "is true for users in the create-room groups" do
      expect(outsider.guardian.can_create_voice_room?).to eq(true)
    end

    it "is false for users outside the create-room groups" do
      expect(low_trust_user.guardian.can_create_voice_room?).to eq(false)
    end

    it "is false for anonymous visitors" do
      expect(anonymous_guardian.can_create_voice_room?).to eq(false)
    end

    it "is false for users outside the voice allowed groups" do
      SiteSetting.voice_allowed_groups = "#{Group::AUTO_GROUPS[:staff]}"

      expect(outsider.guardian.can_create_voice_room?).to eq(false)
    end
  end

  describe "#can_manage_voice_room?" do
    it "is false for a create-room-group user with no tie to the room" do
      expect(outsider.guardian.can_manage_voice_room?(private_room)).to eq(false)
    end

    it "is false for a plain participant member" do
      expect(member.guardian.can_manage_voice_room?(private_room)).to eq(false)
    end

    it "is false for a speaker member" do
      expect(room_speaker.guardian.can_manage_voice_room?(private_room)).to eq(false)
    end

    it "is true for the room creator" do
      expect(creator.guardian.can_manage_voice_room?(private_room)).to eq(true)
    end

    it "is true for a room moderator" do
      expect(room_moderator.guardian.can_manage_voice_room?(private_room)).to eq(true)
    end

    it "is true for site staff" do
      expect(staff.guardian.can_manage_voice_room?(private_room)).to eq(true)
    end

    it "is false for everyone when the plugin is disabled" do
      SiteSetting.voice_enabled = false

      expect(creator.guardian.can_manage_voice_room?(private_room)).to eq(false)
      expect(staff.guardian.can_manage_voice_room?(private_room)).to eq(false)
    end

    it "is false for a create-room-group user on public rooms they don't own" do
      expect(outsider.guardian.can_manage_voice_room?(public_room)).to eq(false)
    end

    it "is false for anonymous visitors" do
      expect(anonymous_guardian.can_manage_voice_room?(public_room)).to eq(false)
    end

    it "is false for a nil room" do
      expect(creator.guardian.can_manage_voice_room?(nil)).to eq(false)
    end
  end

  describe "#can_join_voice_room?" do
    it "lets any allowed user join public rooms" do
      expect(low_trust_user.guardian.can_join_voice_room?(public_room)).to eq(true)
    end

    it "prevents anonymous visitors from joining public rooms" do
      expect(anonymous_guardian.can_join_voice_room?(public_room)).to eq(false)
    end

    it "prevents a create-room-group non-member from joining a private room" do
      expect(outsider.guardian.can_join_voice_room?(private_room)).to eq(false)
    end

    it "lets members join a private room regardless of role" do
      expect(member.guardian.can_join_voice_room?(private_room)).to eq(true)
      expect(room_speaker.guardian.can_join_voice_room?(private_room)).to eq(true)
      expect(room_moderator.guardian.can_join_voice_room?(private_room)).to eq(true)
    end

    it "lets the creator join their private room" do
      expect(creator.guardian.can_join_voice_room?(private_room)).to eq(true)
    end

    it "lets site staff join a private room they aren't a member of" do
      expect(staff.guardian.can_join_voice_room?(private_room)).to eq(true)
    end

    it "prevents users outside the voice allowed groups from joining" do
      SiteSetting.voice_allowed_groups = "#{Group::AUTO_GROUPS[:staff]}"

      expect(member.guardian.can_join_voice_room?(private_room)).to eq(false)
    end
  end

  describe "#can_see_voice_room?" do
    it "lets anonymous visitors see public rooms when anonymous visitors are admitted" do
      expect(anonymous_guardian.can_see_voice_room?(public_room)).to eq(true)
    end

    it "hides public rooms from anonymous visitors on login-required sites" do
      SiteSetting.login_required = true

      expect(anonymous_guardian.can_see_voice_room?(public_room)).to eq(false)
    end

    it "hides private rooms from anonymous visitors" do
      expect(anonymous_guardian.can_see_voice_room?(private_room)).to eq(false)
    end

    it "hides private rooms from a create-room-group non-member" do
      expect(outsider.guardian.can_see_voice_room?(private_room)).to eq(false)
    end

    it "shows private rooms to their members" do
      expect(member.guardian.can_see_voice_room?(private_room)).to eq(true)
    end

    it "shows private rooms to site staff" do
      expect(staff.guardian.can_see_voice_room?(private_room)).to eq(true)
    end
  end

  describe "#can_request_to_speak_in_voice_room?" do
    before { private_room.update!(room_type: Voice::Room::ROOM_TYPE_STAGE) }

    it "is true for a stage-room member with the participant role" do
      expect(member.guardian.can_request_to_speak_in_voice_room?(private_room)).to eq(true)
    end

    it "is false for a stage speaker, who can already speak" do
      expect(room_speaker.guardian.can_request_to_speak_in_voice_room?(private_room)).to eq(false)
    end

    it "is false for a room moderator, who can already speak" do
      expect(room_moderator.guardian.can_request_to_speak_in_voice_room?(private_room)).to eq(false)
    end

    it "is false for site staff, who can already speak" do
      expect(staff.guardian.can_request_to_speak_in_voice_room?(private_room)).to eq(false)
    end

    it "is false in an open room, where everyone can already speak" do
      expect(member.guardian.can_request_to_speak_in_voice_room?(public_room)).to eq(false)
    end

    it "is false for a non-member who cannot join the private stage room" do
      expect(outsider.guardian.can_request_to_speak_in_voice_room?(private_room)).to eq(false)
    end

    it "is false for anonymous visitors" do
      public_room.update!(room_type: Voice::Room::ROOM_TYPE_STAGE)

      expect(anonymous_guardian.can_request_to_speak_in_voice_room?(public_room)).to eq(false)
    end
  end
end

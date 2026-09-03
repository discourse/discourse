# frozen_string_literal: true

require "rails_helper"

RSpec.describe Voice::BadgeGranterHooks do
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:room, :voice_room) { Fabricate(:voice_room, public: true, max_participants: 3) }

  before do
    SiteSetting.voice_enabled = true
    SiteSetting.voice_badges_enabled = true
    SiteSetting.voice_analytics_enabled = true
    SeedFu.seed(Rails.root.join("plugins/voice/db/fixtures"))
    described_class.enable_all!
  end

  describe ".on_leave" do
    def build_session(joined_at:, left_at:)
      Voice::Session.create!(user: user, room: room, joined_at: joined_at, left_at: left_at)
    end

    describe "Mic Check" do
      it "grants when session is 30+ seconds and others are in the room" do
        other = Fabricate(:user)
        Voice::ParticipantTracker.add(room.id, other.id)

        session = build_session(joined_at: 1.minute.ago, left_at: Time.current)
        described_class.on_leave(user, session, room: room)

        expect(user.badges.pluck(:name)).to include("Mic Check")
      end

      it "does not grant when session is under 30 seconds" do
        other = Fabricate(:user)
        Voice::ParticipantTracker.add(room.id, other.id)

        session = build_session(joined_at: 20.seconds.ago, left_at: Time.current)
        described_class.on_leave(user, session, room: room)

        expect(user.badges.pluck(:name)).not_to include("Mic Check")
      end

      it "does not grant when room is empty" do
        session = build_session(joined_at: 1.minute.ago, left_at: Time.current)
        described_class.on_leave(user, session, room: room)

        expect(user.badges.pluck(:name)).not_to include("Mic Check")
      end
    end

    describe "Night Owl" do
      it "grants when session started between midnight and 5 AM in user timezone" do
        user.user_option.update!(timezone: "America/New_York")
        # 2 AM in New York
        joined = Time.zone.parse("2026-03-06 07:00:00 UTC")
        left = joined + 5.minutes

        session = build_session(joined_at: joined, left_at: left)
        described_class.on_leave(user, session, room: room)

        expect(user.badges.pluck(:name)).to include("Night Owl")
      end

      it "does not grant during daytime hours" do
        user.user_option.update!(timezone: "UTC")
        joined = Time.zone.parse("2026-03-06 14:00:00 UTC")
        left = joined + 5.minutes

        session = build_session(joined_at: joined, left_at: left)
        described_class.on_leave(user, session, room: room)

        expect(user.badges.pluck(:name)).not_to include("Night Owl")
      end
    end

    describe "Early Bird" do
      it "grants when session started between 5 AM and 9 AM in user timezone" do
        user.user_option.update!(timezone: "UTC")
        joined = Time.zone.parse("2026-03-06 06:00:00 UTC")
        left = joined + 5.minutes

        session = build_session(joined_at: joined, left_at: left)
        described_class.on_leave(user, session, room: room)

        expect(user.badges.pluck(:name)).to include("Early Bird")
      end
    end

    describe "Marathoner" do
      it "grants when session lasted 4+ hours" do
        session = build_session(joined_at: 5.hours.ago, left_at: Time.current)
        described_class.on_leave(user, session, room: room)

        expect(user.badges.pluck(:name)).to include("Marathoner")
      end

      it "does not grant for shorter sessions" do
        session = build_session(joined_at: 3.hours.ago, left_at: Time.current)
        described_class.on_leave(user, session, room: room)

        expect(user.badges.pluck(:name)).not_to include("Marathoner")
      end
    end

    it "does nothing when badges are disabled" do
      SiteSetting.voice_badges_enabled = false

      session = build_session(joined_at: 5.hours.ago, left_at: Time.current)
      described_class.on_leave(user, session, room: room)

      expect(user.badges).to be_empty
    end

    it "does nothing when session has no left_at" do
      session = Voice::Session.create!(user: user, room: room, joined_at: 5.hours.ago)
      described_class.on_leave(user, session, room: room)

      expect(user.badges).to be_empty
    end
  end

  describe ".on_join" do
    describe "Packed House" do
      it "grants when room reaches max capacity" do
        other1 = Fabricate(:user)
        other2 = Fabricate(:user)
        participants = User.where(id: [user.id, other1.id, other2.id])

        described_class.on_join(user, room, participants)

        expect(user.badges.pluck(:name)).to include("Packed House")
      end

      it "does not grant when room has no max_participants" do
        room.update!(max_participants: nil)
        participants = User.where(id: [user.id])

        described_class.on_join(user, room, participants)

        expect(user.badges.pluck(:name)).not_to include("Packed House")
      end
    end

    describe "Icebreaker" do
      fab!(:stranger, :user)

      it "grants when user has no co-presence history with anyone in the room" do
        Voice::ParticipantTracker.add(room.id, stranger.id)
        participants = User.where(id: [user.id, stranger.id])

        described_class.on_join(user, room, participants)

        expect(user.badges.pluck(:name)).to include("Icebreaker")
      end

      it "does not grant when user has co-presence history" do
        ids = [user.id, stranger.id].sort
        Voice::CoPresence.create!(
          user_id_1: ids.first,
          user_id_2: ids.last,
          date: Date.current,
          total_seconds: 60,
          session_count: 1,
        )
        participants = User.where(id: [user.id, stranger.id])

        described_class.on_join(user, room, participants)

        expect(user.badges.pluck(:name)).not_to include("Icebreaker")
      end

      it "does not grant when user is alone in the room" do
        participants = User.where(id: [user.id])

        described_class.on_join(user, room, participants)

        expect(user.badges.pluck(:name)).not_to include("Icebreaker")
      end
    end
  end

  describe ".on_room_create" do
    it "grants Host badge" do
      described_class.on_room_create(user)

      expect(user.badges.pluck(:name)).to include("Host")
    end

    it "does nothing when badges are disabled" do
      SiteSetting.voice_badges_enabled = false

      described_class.on_room_create(user)

      expect(user.badges).to be_empty
    end
  end

  describe ".on_invite_redeemed" do
    fab!(:invitee) { Fabricate(:user, trust_level: TrustLevel[2]) }

    def redeemed_invite
      Voice::Invite.create!(
        room_id: room.id,
        user_id: invitee.id,
        invited_by_id: user.id,
        redeemed_at: Time.current,
      )
    end

    it "grants Plus One to the inviter" do
      described_class.on_invite_redeemed(redeemed_invite)

      expect(user.badges.pluck(:name)).to include("Plus One")
      expect(invitee.badges).to be_empty
    end

    it "does nothing when badges are disabled" do
      SiteSetting.voice_badges_enabled = false

      described_class.on_invite_redeemed(redeemed_invite)

      expect(user.badges).to be_empty
    end
  end

  describe "fixture seeding" do
    def voice_badges
      Badge.joins(:badge_grouping).where(badge_groupings: { name: "Voice" })
    end

    it "creates all badges as disabled" do
      described_class.disable_all!

      expect(voice_badges.count).to eq(27)
      expect(voice_badges.where(enabled: true).count).to eq(0)
    end

    it "creates the Voice badge grouping" do
      expect(BadgeGrouping.exists?(name: "Voice")).to eq(true)
    end

    it "is idempotent" do
      expect { SeedFu.seed(Rails.root.join("plugins/voice/db/fixtures")) }.not_to change {
        Badge.count
      }
    end

    it "sets SQL queries on scheduled badges" do
      expect(Badge.find_by(name: "Rookie").query).to include("voice_sessions")
      expect(Badge.find_by(name: "Social Butterfly").query).to include("voice_co_presences")
    end

    it "does not set queries on instant badges" do
      %w[Mic\ Check Host Icebreaker Packed\ House Night\ Owl Early\ Bird Marathoner].each do |name|
        expect(Badge.find_by(name: name).query).to be_nil, "Expected #{name} to have no query"
      end
    end

    it "allows gold badges to be used as title" do
      gold_badges = voice_badges.where(badge_type_id: BadgeType::Gold)
      expect(gold_badges).to all(have_attributes(allow_title: true))
    end
  end

  describe ".enable_all!" do
    before { described_class.disable_all! }

    it "enables all Voice badges" do
      described_class.enable_all!

      voice_badges = Badge.joins(:badge_grouping).where(badge_groupings: { name: "Voice" })
      expect(voice_badges.where(enabled: false).count).to eq(0)
    end
  end

  describe ".disable_all!" do
    it "disables all Voice badges" do
      described_class.disable_all!

      voice_badges = Badge.joins(:badge_grouping).where(badge_groupings: { name: "Voice" })
      expect(voice_badges.where(enabled: true).count).to eq(0)
    end
  end
end

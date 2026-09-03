# frozen_string_literal: true

require "rails_helper"

RSpec.describe BadgeGranter, ".backfill" do
  fab!(:user)
  fab!(:room, :voice_room)

  before do
    SiteSetting.voice_enabled = true
    SiteSetting.voice_badges_enabled = true
    SeedFu.seed(Rails.root.join("plugins/voice/db/fixtures"))
    Voice::BadgeGranterHooks.enable_all!
  end

  def backfill(badge_name)
    BadgeGranter.backfill(Badge.find_by!(name: badge_name))
  end

  def holders_of(badge_name)
    UserBadge.joins(:badge).where(badges: { name: badge_name }).pluck(:user_id)
  end

  def create_session(user_id:, room_id: room.id, joined_at:, duration: 10.minutes)
    Voice::Session.create!(
      user_id: user_id,
      room_id: room_id,
      joined_at: joined_at,
      left_at: joined_at + duration,
    )
  end

  # Session and co-presence rows only reference user ids, so partners need not
  # be real users; the grantee does, since core joins the users table.
  def create_co_presence(user_id, partner_id, total_seconds:, date: Date.current)
    first, second = [user_id, partner_id].sort
    Voice::CoPresence.create!(
      user_id_1: first,
      user_id_2: second,
      date: date,
      total_seconds: total_seconds,
      session_count: 1,
    )
  end

  describe "airtime" do
    it "grants Rookie at one hour of total session time" do
      create_session(user_id: user.id, joined_at: 3.hours.ago, duration: 30.minutes)
      create_session(user_id: user.id, joined_at: 2.hours.ago, duration: 29.minutes)
      backfill("Rookie")
      expect(holders_of("Rookie")).to be_empty

      create_session(user_id: user.id, joined_at: 1.hour.ago, duration: 1.minute)
      backfill("Rookie")
      expect(holders_of("Rookie")).to contain_exactly(user.id)
    end

    it "counts an open session up to now" do
      Voice::Session.create!(user: user, room: room, joined_at: 61.minutes.ago, left_at: nil)

      backfill("Rookie")

      expect(holders_of("Rookie")).to contain_exactly(user.id)
    end

    it "keeps the badge once the sessions that earned it are purged" do
      create_session(user_id: user.id, joined_at: 2.hours.ago, duration: 1.hour)
      backfill("Rookie")
      Voice::Session.delete_all

      backfill("Rookie")

      expect(holders_of("Rookie")).to contain_exactly(user.id)
    end
  end

  describe "networker" do
    it "grants Social Butterfly for ten partners with at least five minutes each" do
      9.times { |index| create_co_presence(user.id, 100_000 + index, total_seconds: 300) }
      create_co_presence(user.id, 200_000, total_seconds: 299)
      backfill("Social Butterfly")
      expect(holders_of("Social Butterfly")).to be_empty

      create_co_presence(user.id, 200_000, total_seconds: 1, date: Date.yesterday)
      backfill("Social Butterfly")
      expect(holders_of("Social Butterfly")).to contain_exactly(user.id)
    end
  end

  describe "bonding" do
    fab!(:partner, :user)

    it "grants Familiar Face to both sides after two hours together across days" do
      create_co_presence(user.id, partner.id, total_seconds: 1.hour.to_i)
      create_co_presence(user.id, 100_001, total_seconds: 1.hour.to_i)
      backfill("Familiar Face")
      expect(holders_of("Familiar Face")).to be_empty

      create_co_presence(user.id, partner.id, total_seconds: 1.hour.to_i, date: Date.yesterday)
      backfill("Familiar Face")
      expect(holders_of("Familiar Face")).to contain_exactly(user.id, partner.id)
    end
  end

  describe "exploration" do
    it "grants Explorer for five distinct rooms" do
      rooms = Array.new(4) { Fabricate(:voice_room) }
      rooms.each do |visited|
        2.times { create_session(user_id: user.id, room_id: visited.id, joined_at: 1.day.ago) }
      end
      backfill("Explorer")
      expect(holders_of("Explorer")).to be_empty

      create_session(user_id: user.id, joined_at: 1.hour.ago)
      backfill("Explorer")
      expect(holders_of("Explorer")).to contain_exactly(user.id)
    end
  end

  describe "loyalty" do
    it "grants Patron for ten distinct days in the same room" do
      9.times do |day|
        create_session(user_id: user.id, joined_at: (day + 1).days.ago.change(hour: 12))
        create_session(user_id: user.id, joined_at: (day + 1).days.ago.change(hour: 14))
      end
      create_session(user_id: user.id, room_id: Fabricate(:voice_room).id, joined_at: 1.hour.ago)
      backfill("Patron")
      expect(holders_of("Patron")).to be_empty

      create_session(user_id: user.id, joined_at: 10.days.ago.change(hour: 12))
      backfill("Patron")
      expect(holders_of("Patron")).to contain_exactly(user.id)
    end
  end

  describe "hosting" do
    fab!(:hosted_room, :voice_room) { Fabricate(:voice_room, creator: user) }

    it "grants Crowd Puller for fifty distinct visitors, ignoring repeat and self joins" do
      49.times do |index|
        create_session(user_id: 100_000 + index, room_id: hosted_room.id, joined_at: 1.day.ago)
      end
      5.times { create_session(user_id: 100_000, room_id: hosted_room.id, joined_at: 1.hour.ago) }
      5.times { create_session(user_id: user.id, room_id: hosted_room.id, joined_at: 1.hour.ago) }
      backfill("Crowd Puller")
      expect(holders_of("Crowd Puller")).to be_empty

      create_session(user_id: 200_000, room_id: hosted_room.id, joined_at: 1.hour.ago)
      backfill("Crowd Puller")
      expect(holders_of("Crowd Puller")).to contain_exactly(user.id)
    end
  end

  describe "inviting" do
    def create_invite(invitee_id, redeemed: true)
      Voice::Invite.create!(
        room_id: room.id,
        user_id: invitee_id,
        invited_by_id: user.id,
        redeemed_at: redeemed ? Time.current : nil,
      )
    end

    it "grants Connector for ten distinct redeemed invitees" do
      9.times { |index| create_invite(100_000 + index) }
      create_invite(200_000, redeemed: false)
      Voice::Invite.create!(
        room_id: Fabricate(:voice_room).id,
        user_id: 100_000,
        invited_by_id: user.id,
        redeemed_at: Time.current,
      )
      backfill("Connector")
      expect(holders_of("Connector")).to be_empty

      create_invite(300_000)
      backfill("Connector")
      expect(holders_of("Connector")).to contain_exactly(user.id)
    end
  end

  describe "Weekend Warrior" do
    it "grants for five hours of weekend sessions only" do
      saturday = Time.zone.parse("2026-08-29 10:00 UTC")
      monday = Time.zone.parse("2026-08-31 10:00 UTC")
      create_session(user_id: user.id, joined_at: monday, duration: 6.hours)
      create_session(user_id: user.id, joined_at: saturday, duration: 4.hours)
      backfill("Weekend Warrior")
      expect(holders_of("Weekend Warrior")).to be_empty

      create_session(user_id: user.id, joined_at: saturday + 1.day, duration: 1.hour)
      backfill("Weekend Warrior")
      expect(holders_of("Weekend Warrior")).to contain_exactly(user.id)
    end
  end
end

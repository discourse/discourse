# frozen_string_literal: true

require "rails_helper"

RSpec.describe Live::UserStatusManager do
  fab!(:user)
  fab!(:room) { Fabricate(:live_room, public: true) }
  fab!(:private_room) { Fabricate(:live_room, public: false) }

  before do
    SiteSetting.live_enabled = true
    SiteSetting.enable_user_status = true
    SiteSetting.live_auto_status_enabled = true
  end

  describe ".set_live_status" do
    it "leaves agent status unchanged" do
      bot = Fabricate(:user, id: -1400)

      described_class.set_live_status(bot, room)

      expect(bot.reload.user_status).to be_nil
    end

    it "sets the user's status with room name and no expiry" do
      described_class.set_live_status(user, room)

      user.reload
      expect(user.user_status.description).to eq("In #{room.name}")
      expect(user.user_status.emoji).to eq("studio_microphone")
      expect(user.user_status.ends_at).to be_nil
    end

    it "does not republish an unchanged status" do
      described_class.set_live_status(user, room)

      messages = MessageBus.track_publish { described_class.set_live_status(user, room) }

      expect(messages).to be_empty
    end

    it "does not leak the name of a private room" do
      described_class.set_live_status(user, private_room)

      user.reload
      expect(user.user_status.description).to eq("In a live room")
      expect(user.user_status.description).not_to include(private_room.name)
    end

    it "skips when user already has a non-Live status" do
      user.set_status!("On vacation", "palm_tree")

      described_class.set_live_status(user, room)

      user.reload
      expect(user.user_status.emoji).to eq("palm_tree")
    end

    it "overwrites an existing Live status" do
      user.set_status!("In Old Room", "studio_microphone")

      described_class.set_live_status(user, room)

      user.reload
      expect(user.user_status.description).to eq("In #{room.name}")
    end

    it "rewrites a matching status that still carries an expiry" do
      user.set_status!("In #{room.name}", "studio_microphone", 2.minutes.from_now)

      described_class.set_live_status(user, room)

      expect(user.reload.user_status.ends_at).to be_nil
    end

    it "skips when enable_user_status is false" do
      SiteSetting.enable_user_status = false

      described_class.set_live_status(user, room)

      expect(user.user_status).to be_nil
    end

    it "skips when live_auto_status_enabled is false" do
      SiteSetting.live_auto_status_enabled = false

      described_class.set_live_status(user, room)

      expect(user.user_status).to be_nil
    end
  end

  describe ".set_afk_status" do
    it "transitions to AFK status when Live owns the current status" do
      described_class.set_live_status(user, room)
      described_class.set_afk_status(user, room)

      user.reload
      expect(user.user_status.description).to eq("AFK in #{room.name}")
      expect(user.user_status.emoji).to eq("zzz")
      expect(user.user_status.ends_at).to be_nil
    end

    it "does not leak the name of a private room" do
      described_class.set_live_status(user, private_room)
      described_class.set_afk_status(user, private_room)

      user.reload
      expect(user.user_status.description).to eq("AFK in a live room")
      expect(user.user_status.description).not_to include(private_room.name)
    end

    it "skips when the user has a non-Live status" do
      user.set_status!("On vacation", "palm_tree")

      described_class.set_afk_status(user, room)

      user.reload
      expect(user.user_status.emoji).to eq("palm_tree")
    end

    it "skips when user has no status" do
      described_class.set_afk_status(user, room)

      expect(user.user_status).to be_nil
    end
  end

  describe ".clear_live_status" do
    it "clears status when Live owns it" do
      described_class.set_live_status(user, room)
      described_class.clear_live_status(user)

      user.reload
      expect(user.user_status).to be_nil
    end

    it "clears AFK status" do
      described_class.set_live_status(user, room)
      described_class.set_afk_status(user, room)
      described_class.clear_live_status(user)

      user.reload
      expect(user.user_status).to be_nil
    end

    it "does not clear a non-Live status" do
      user.set_status!("On vacation", "palm_tree")

      described_class.clear_live_status(user)

      user.reload
      expect(user.user_status.emoji).to eq("palm_tree")
    end

    it "does nothing when user has no status" do
      expect { described_class.clear_live_status(user) }.not_to raise_error
    end
  end

  describe ".clear_stale_statuses" do
    fab!(:other_user, :user)

    it "clears statuses owned before the plugin rename" do
      user.set_status!("In Watercooler", "studio_microphone")
      other_user.set_status!("AFK in Watercooler", "zzz")
      Discourse.redis.sadd("voice:status_owners", [user.id, other_user.id])
      freeze_time(1.minute.from_now)

      described_class.clear_stale_statuses([])

      expect(user.reload.user_status).to be_nil
      expect(other_user.reload.user_status).to be_nil
      expect(Discourse.redis.smembers("voice:status_owners")).to be_empty
    end

    it "clears Live statuses of users not in the live set" do
      described_class.set_live_status(user, room)
      described_class.set_live_status(other_user, room)
      described_class.set_afk_status(other_user, room)
      freeze_time(1.minute.from_now)

      described_class.clear_stale_statuses([user.id])

      expect(user.reload.user_status).to be_present
      expect(other_user.reload.user_status).to be_nil
    end

    it "clears everything when no one is live" do
      described_class.set_live_status(user, room)
      freeze_time(1.minute.from_now)

      described_class.clear_stale_statuses([])

      expect(user.reload.user_status).to be_nil
    end

    it "leaves a freshly set status for the next sweep" do
      described_class.set_live_status(user, room)

      described_class.clear_stale_statuses([])

      expect(user.reload.user_status).to be_present
    end

    it "does not touch non-Live statuses" do
      user.set_status!("On vacation", "palm_tree")
      freeze_time(1.minute.from_now)

      described_class.clear_stale_statuses([])

      expect(user.reload.user_status.emoji).to eq("palm_tree")
    end

    it "does not clear a manually set status that uses a Live emoji" do
      user.set_status!("Sleeping", "zzz")
      freeze_time(1.minute.from_now)

      described_class.clear_stale_statuses([])

      expect(user.reload.user_status.emoji).to eq("zzz")
    end

    it "does not clear a manual status that replaced a Live one" do
      described_class.set_live_status(user, room)
      user.set_status!("On vacation", "palm_tree")
      freeze_time(1.minute.from_now)

      described_class.clear_stale_statuses([])

      expect(user.reload.user_status.emoji).to eq("palm_tree")
    end

    it "skips when enable_user_status is false" do
      described_class.set_live_status(user, room)
      SiteSetting.enable_user_status = false
      freeze_time(1.minute.from_now)

      described_class.clear_stale_statuses([])

      expect(user.reload.user_status).to be_present
    end
  end

  describe ".live_status_active?" do
    it "returns true for studio_microphone emoji" do
      user.set_status!("In Room", "studio_microphone", 2.minutes.from_now)
      expect(described_class.live_status_active?(user)).to eq(true)
    end

    it "returns true for zzz emoji" do
      user.set_status!("AFK in Room", "zzz", 2.minutes.from_now)
      expect(described_class.live_status_active?(user)).to eq(true)
    end

    it "returns false for other emojis" do
      user.set_status!("On vacation", "palm_tree")
      expect(described_class.live_status_active?(user)).to eq(false)
    end

    it "returns false when user has no status" do
      expect(described_class.live_status_active?(user)).to be_falsey
    end

    it "returns false when status is expired" do
      user.set_status!("In Room", "studio_microphone", 1.minute.from_now)
      freeze_time(2.minutes.from_now)
      expect(described_class.live_status_active?(user)).to eq(false)
    end
  end
end

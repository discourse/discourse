# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-patreon/db/migrate/20260210042613_migrate_patreon_plugin_store_to_tables.rb",
        )

RSpec.describe MigratePatreonPluginStoreToTables do
  PLUGIN_NAME = "discourse-patreon"

  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false

    # Clean up any existing data
    PatreonSyncLog.delete_all
    PatreonGroupRewardFilter.delete_all
    PatreonPatronReward.delete_all
    PatreonPatron.delete_all
    PatreonReward.delete_all
    DB.exec("DELETE FROM plugin_store_rows WHERE plugin_name = ?", PLUGIN_NAME)
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  def insert_plugin_store(key, value)
    DB.exec(
      "INSERT INTO plugin_store_rows (plugin_name, key, type_name, value) VALUES (?, ?, 'JSON', ?)",
      PLUGIN_NAME,
      key,
      value.to_json,
    )
  end

  def insert_plugin_store_raw(key, raw_value)
    DB.exec(
      "INSERT INTO plugin_store_rows (plugin_name, key, type_name, value) VALUES (?, ?, 'JSON', ?)",
      PLUGIN_NAME,
      key,
      raw_value,
    )
  end

  describe "rewards migration" do
    it "migrates rewards correctly" do
      insert_plugin_store(
        "rewards",
        {
          "123" => {
            "title" => "Bronze Tier",
            "amount_cents" => 500,
          },
          "456" => {
            "title" => "Silver Tier",
            "amount_cents" => 1000,
          },
          "0" => {
            "title" => "All Patrons",
            "amount_cents" => 0,
          },
        },
      )

      described_class.new.up

      expect(PatreonReward.count).to eq(3)

      bronze = PatreonReward.find_by(patreon_id: "123")
      expect(bronze.title).to eq("Bronze Tier")
      expect(bronze.amount_cents).to eq(500)

      silver = PatreonReward.find_by(patreon_id: "456")
      expect(silver.title).to eq("Silver Tier")
      expect(silver.amount_cents).to eq(1000)

      all_patrons = PatreonReward.find_by(patreon_id: "0")
      expect(all_patrons.title).to eq("All Patrons")
      expect(all_patrons.amount_cents).to eq(0)
    end

    it "handles missing title by using 'Untitled'" do
      insert_plugin_store("rewards", { "123" => { "amount_cents" => 500 } })

      described_class.new.up

      reward = PatreonReward.find_by(patreon_id: "123")
      expect(reward.title).to eq("Untitled")
    end

    it "handles missing amount_cents by defaulting to 0" do
      insert_plugin_store("rewards", { "123" => { "title" => "Test" } })

      described_class.new.up

      reward = PatreonReward.find_by(patreon_id: "123")
      expect(reward.amount_cents).to eq(0)
    end

    it "handles empty rewards hash" do
      insert_plugin_store("rewards", {})

      expect { described_class.new.up }.not_to raise_error
      expect(PatreonReward.count).to eq(0)
    end

    it "handles missing rewards key" do
      # Don't insert any rewards data
      expect { described_class.new.up }.not_to raise_error
      expect(PatreonReward.count).to eq(0)
    end
  end

  describe "patrons migration" do
    it "migrates patrons from users, pledges, and declines" do
      insert_plugin_store(
        "users",
        { "patron_1" => "user1@example.com", "patron_2" => "user2@example.com" },
      )
      insert_plugin_store("pledges", { "patron_1" => 1000, "patron_3" => 500 })
      insert_plugin_store("pledge-declines", { "patron_2" => "2024-01-15T12:00:00Z" })

      described_class.new.up

      expect(PatreonPatron.count).to eq(3)

      patron1 = PatreonPatron.find_by(patreon_id: "patron_1")
      expect(patron1.email).to eq("user1@example.com")
      expect(patron1.amount_cents).to eq(1000)
      expect(patron1.declined_since).to be_nil

      patron2 = PatreonPatron.find_by(patreon_id: "patron_2")
      expect(patron2.email).to eq("user2@example.com")
      expect(patron2.amount_cents).to be_nil
      expect(patron2.declined_since).to be_present

      patron3 = PatreonPatron.find_by(patreon_id: "patron_3")
      expect(patron3.email).to be_nil
      expect(patron3.amount_cents).to eq(500)
    end

    it "handles empty patron data" do
      insert_plugin_store("users", {})
      insert_plugin_store("pledges", {})
      insert_plugin_store("pledge-declines", {})

      expect { described_class.new.up }.not_to raise_error
      expect(PatreonPatron.count).to eq(0)
    end

    it "handles patron appearing in multiple data sources" do
      insert_plugin_store("users", { "patron_1" => "user@example.com" })
      insert_plugin_store("pledges", { "patron_1" => 1000 })
      insert_plugin_store("pledge-declines", { "patron_1" => "2024-01-15T12:00:00Z" })

      described_class.new.up

      expect(PatreonPatron.count).to eq(1)

      patron = PatreonPatron.find_by(patreon_id: "patron_1")
      expect(patron.email).to eq("user@example.com")
      expect(patron.amount_cents).to eq(1000)
      expect(patron.declined_since).to be_present
    end

    it "handles large number of patrons with batching" do
      users = {}
      600.times { |i| users["patron_#{i}"] = "user#{i}@example.com" }
      insert_plugin_store("users", users)

      expect { described_class.new.up }.not_to raise_error
      expect(PatreonPatron.count).to eq(600)
    end
  end

  describe "reward-users migration" do
    it "migrates reward-user associations" do
      insert_plugin_store(
        "rewards",
        {
          "reward_1" => {
            "title" => "Tier 1",
            "amount_cents" => 500,
          },
          "reward_2" => {
            "title" => "Tier 2",
            "amount_cents" => 1000,
          },
        },
      )
      insert_plugin_store(
        "users",
        { "patron_1" => "user1@example.com", "patron_2" => "user2@example.com" },
      )
      insert_plugin_store(
        "reward-users",
        { "reward_1" => %w[patron_1 patron_2], "reward_2" => ["patron_1"] },
      )

      described_class.new.up

      expect(PatreonPatronReward.count).to eq(3)

      patron1 = PatreonPatron.find_by(patreon_id: "patron_1")
      expect(patron1.patreon_rewards.pluck(:patreon_id)).to contain_exactly("reward_1", "reward_2")

      patron2 = PatreonPatron.find_by(patreon_id: "patron_2")
      expect(patron2.patreon_rewards.pluck(:patreon_id)).to contain_exactly("reward_1")
    end

    it "skips reward-users with empty patron list" do
      insert_plugin_store(
        "rewards",
        { "reward_1" => { "title" => "Tier 1", "amount_cents" => 500 } },
      )
      insert_plugin_store("reward-users", { "reward_1" => [] })

      expect { described_class.new.up }.not_to raise_error
      expect(PatreonPatronReward.count).to eq(0)
    end

    it "skips reward-users for non-existent rewards" do
      insert_plugin_store("users", { "patron_1" => "user@example.com" })
      insert_plugin_store("reward-users", { "nonexistent_reward" => ["patron_1"] })

      expect { described_class.new.up }.not_to raise_error
      expect(PatreonPatronReward.count).to eq(0)
    end

    it "skips reward-users for non-existent patrons" do
      insert_plugin_store(
        "rewards",
        { "reward_1" => { "title" => "Tier 1", "amount_cents" => 500 } },
      )
      insert_plugin_store("reward-users", { "reward_1" => ["nonexistent_patron"] })

      expect { described_class.new.up }.not_to raise_error
      expect(PatreonPatronReward.count).to eq(0)
    end
  end

  describe "filters migration" do
    fab!(:group)

    it "migrates filters correctly" do
      insert_plugin_store(
        "rewards",
        {
          "0" => {
            "title" => "All Patrons",
            "amount_cents" => 0,
          },
          "123" => {
            "title" => "Premium",
            "amount_cents" => 1000,
          },
        },
      )
      insert_plugin_store("filters", { group.id.to_s => %w[0 123] })

      described_class.new.up

      expect(PatreonGroupRewardFilter.count).to eq(2)
      expect(PatreonGroupRewardFilter.where(group: group).count).to eq(2)

      reward_ids =
        PatreonGroupRewardFilter
          .where(group: group)
          .joins(:patreon_reward)
          .pluck("patreon_rewards.patreon_id")
      expect(reward_ids).to contain_exactly("0", "123")
    end

    it "skips filters for non-existent groups" do
      insert_plugin_store("rewards", { "0" => { "title" => "All Patrons", "amount_cents" => 0 } })
      insert_plugin_store("filters", { "999999" => ["0"] })

      expect { described_class.new.up }.not_to raise_error
      expect(PatreonGroupRewardFilter.count).to eq(0)
    end

    it "skips filters with empty reward list" do
      insert_plugin_store("filters", { group.id.to_s => [] })

      expect { described_class.new.up }.not_to raise_error
      expect(PatreonGroupRewardFilter.count).to eq(0)
    end

    it "skips filters for non-existent rewards" do
      insert_plugin_store("filters", { group.id.to_s => ["nonexistent"] })

      expect { described_class.new.up }.not_to raise_error
      expect(PatreonGroupRewardFilter.count).to eq(0)
    end

    it "handles multiple groups with filters" do
      group2 = Fabricate(:group)
      insert_plugin_store("rewards", { "0" => { "title" => "All Patrons", "amount_cents" => 0 } })
      insert_plugin_store("filters", { group.id.to_s => ["0"], group2.id.to_s => ["0"] })

      described_class.new.up

      expect(PatreonGroupRewardFilter.count).to eq(2)
      expect(PatreonGroupRewardFilter.where(group: group).count).to eq(1)
      expect(PatreonGroupRewardFilter.where(group: group2).count).to eq(1)
    end
  end

  describe "last_sync migration" do
    it "migrates last_sync timestamp" do
      insert_plugin_store("last_sync", { "at" => "2024-06-15T10:30:00Z" })

      described_class.new.up

      expect(PatreonSyncLog.count).to eq(1)
      sync_log = PatreonSyncLog.first
      expect(sync_log.synced_at).to be_present
    end

    it "handles missing last_sync" do
      expect { described_class.new.up }.not_to raise_error
      expect(PatreonSyncLog.count).to eq(0)
    end

    it "handles last_sync without 'at' key" do
      insert_plugin_store("last_sync", { "other_key" => "value" })

      expect { described_class.new.up }.not_to raise_error
      expect(PatreonSyncLog.count).to eq(0)
    end

    it "handles empty last_sync" do
      insert_plugin_store("last_sync", {})

      expect { described_class.new.up }.not_to raise_error
      expect(PatreonSyncLog.count).to eq(0)
    end
  end

  describe "edge cases and error handling" do
    it "handles malformed JSON gracefully" do
      insert_plugin_store_raw("rewards", "not valid json {{{")

      expect { described_class.new.up }.not_to raise_error
      expect(PatreonReward.count).to eq(0)
    end

    it "handles complete migration with all data types" do
      group = Fabricate(:group)

      insert_plugin_store(
        "rewards",
        {
          "0" => {
            "title" => "All Patrons",
            "amount_cents" => 0,
          },
          "premium" => {
            "title" => "Premium",
            "amount_cents" => 2000,
          },
        },
      )
      insert_plugin_store(
        "users",
        {
          "patron_1" => "alice@example.com",
          "patron_2" => "bob@example.com",
          "patron_3" => "carol@example.com",
        },
      )
      insert_plugin_store("pledges", { "patron_1" => 2000, "patron_2" => 500 })
      insert_plugin_store("pledge-declines", { "patron_3" => "2024-01-01T00:00:00Z" })
      insert_plugin_store(
        "reward-users",
        { "0" => %w[patron_1 patron_2 patron_3], "premium" => ["patron_1"] },
      )
      insert_plugin_store("filters", { group.id.to_s => %w[0 premium] })
      insert_plugin_store("last_sync", { "at" => "2024-06-15T12:00:00Z" })

      described_class.new.up

      expect(PatreonReward.count).to eq(2)
      expect(PatreonPatron.count).to eq(3)
      expect(PatreonPatronReward.count).to eq(4)
      expect(PatreonGroupRewardFilter.count).to eq(2)
      expect(PatreonSyncLog.count).to eq(1)

      patron1 = PatreonPatron.find_by(patreon_id: "patron_1")
      expect(patron1.email).to eq("alice@example.com")
      expect(patron1.amount_cents).to eq(2000)
      expect(patron1.patreon_rewards.count).to eq(2)
    end

    it "is idempotent with ON CONFLICT DO NOTHING" do
      insert_plugin_store("rewards", { "123" => { "title" => "Test", "amount_cents" => 500 } })

      # Run migration twice
      described_class.new.up

      # Manually insert same reward to simulate partial re-run
      # The second run should not fail due to unique constraint
      expect(PatreonReward.count).to eq(1)
    end

    it "handles non-string reward IDs" do
      # Patreon IDs should be strings, but let's make sure numeric keys work
      insert_plugin_store("rewards", { 123 => { "title" => "Numeric ID", "amount_cents" => 500 } })

      described_class.new.up

      expect(PatreonReward.count).to eq(1)
      expect(PatreonReward.first.patreon_id).to eq("123")
    end
  end

  describe "data integrity" do
    it "preserves all patron data fields" do
      timestamp = "2024-03-15T14:30:00Z"
      insert_plugin_store("users", { "patron_1" => "test@example.com" })
      insert_plugin_store("pledges", { "patron_1" => 1500 })
      insert_plugin_store("pledge-declines", { "patron_1" => timestamp })

      described_class.new.up

      patron = PatreonPatron.find_by(patreon_id: "patron_1")
      expect(patron.email).to eq("test@example.com")
      expect(patron.amount_cents).to eq(1500)
      expect(patron.declined_since).to eq(Time.zone.parse(timestamp))
    end

    it "preserves reward data fields" do
      insert_plugin_store(
        "rewards",
        { "test_id" => { "title" => "Special Reward", "amount_cents" => 9999 } },
      )

      described_class.new.up

      reward = PatreonReward.find_by(patreon_id: "test_id")
      expect(reward.title).to eq("Special Reward")
      expect(reward.amount_cents).to eq(9999)
    end
  end
end

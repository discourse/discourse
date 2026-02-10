# frozen_string_literal: true

class MigratePatreonPluginStoreToTables < ActiveRecord::Migration[7.2]
  PLUGIN_NAME = "discourse-patreon"

  def up
    plugin_store_rows =
      DB.query("SELECT key, value FROM plugin_store_rows WHERE plugin_name = ?", PLUGIN_NAME)

    data = {}
    plugin_store_rows.each do |row|
      data[row.key] = begin
        JSON.parse(row.value)
      rescue StandardError
        nil
      end
    end

    # 1. Migrate rewards
    rewards = data["rewards"] || {}
    reward_rows =
      rewards.map do |patreon_id, attrs|
        title = attrs["title"] || "Untitled"
        amount_cents = attrs["amount_cents"].to_i
        now = Time.zone.now
        {
          patreon_id: patreon_id,
          title: title,
          amount_cents: amount_cents,
          created_at: now,
          updated_at: now,
        }
      end

    if reward_rows.present?
      DB.exec(
        <<~SQL,
        INSERT INTO patreon_rewards (patreon_id, title, amount_cents, created_at, updated_at)
        VALUES #{reward_rows.map { "(?::varchar, ?::varchar, ?::integer, ?::timestamp, ?::timestamp)" }.join(", ")}
        ON CONFLICT (patreon_id) DO NOTHING
      SQL
        reward_rows
          .map { |r| [r[:patreon_id], r[:title], r[:amount_cents], r[:created_at], r[:updated_at]] }
          .flatten,
      )
    end

    # 2. Migrate patrons (merge users, pledges, pledge-declines)
    users = data["users"] || {}
    pledges = data["pledges"] || {}
    declines = data["pledge-declines"] || {}

    patron_ids = (users.keys + pledges.keys + declines.keys).uniq
    patron_rows =
      patron_ids.map do |patreon_id|
        now = Time.zone.now
        {
          patreon_id: patreon_id,
          email: users[patreon_id],
          amount_cents: pledges[patreon_id]&.to_i,
          declined_since: declines[patreon_id],
          created_at: now,
          updated_at: now,
        }
      end

    patron_rows.each_slice(500) do |batch|
      values =
        batch.map do |r|
          "(#{DB.param_encoder.encode(r[:patreon_id])}, #{DB.param_encoder.encode(r[:email])}, #{r[:amount_cents].nil? ? "NULL" : r[:amount_cents]}, #{r[:declined_since].nil? ? "NULL" : DB.param_encoder.encode(r[:declined_since].to_s) + "::timestamp"}, #{DB.param_encoder.encode(r[:created_at].iso8601)}::timestamp, #{DB.param_encoder.encode(r[:updated_at].iso8601)}::timestamp)"
        end

      DB.exec(<<~SQL) if values.present?
        INSERT INTO patreon_patrons (patreon_id, email, amount_cents, declined_since, created_at, updated_at)
        VALUES #{values.join(", ")}
        ON CONFLICT (patreon_id) DO NOTHING
      SQL
    end

    # 3. Migrate reward-users (join table)
    reward_users = data["reward-users"] || {}
    reward_users.each do |reward_patreon_id, patron_patreon_ids|
      next if patron_patreon_ids.blank?

      DB.exec(<<~SQL, reward_patreon_id: reward_patreon_id, patron_patreon_ids: patron_patreon_ids)
        INSERT INTO patreon_patron_rewards (patreon_patron_id, patreon_reward_id, created_at, updated_at)
        SELECT pp.id, pr.id, NOW(), NOW()
        FROM patreon_patrons pp
        CROSS JOIN patreon_rewards pr
        WHERE pp.patreon_id = ANY(ARRAY[:patron_patreon_ids]::varchar[])
          AND pr.patreon_id = :reward_patreon_id
        ON CONFLICT DO NOTHING
      SQL
    end

    # 4. Migrate filters (critical admin-configured data)
    filters = data["filters"] || {}
    filters.each do |group_id, reward_patreon_ids|
      next if reward_patreon_ids.blank?
      next if DB.query_single("SELECT 1 FROM groups WHERE id = ?", group_id.to_i).blank?

      DB.exec(<<~SQL, group_id: group_id.to_i, reward_patreon_ids: reward_patreon_ids)
        INSERT INTO patreon_group_reward_filters (group_id, patreon_reward_id, created_at, updated_at)
        SELECT :group_id, pr.id, NOW(), NOW()
        FROM patreon_rewards pr
        WHERE pr.patreon_id = ANY(ARRAY[:reward_patreon_ids]::varchar[])
        ON CONFLICT DO NOTHING
      SQL
    end

    # 5. Migrate last_sync
    last_sync = data["last_sync"]
    if last_sync.present? && last_sync["at"].present?
      DB.exec(
        "INSERT INTO patreon_sync_logs (synced_at, created_at, updated_at) VALUES (?::timestamp, NOW(), NOW())",
        last_sync["at"].to_s,
      )
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

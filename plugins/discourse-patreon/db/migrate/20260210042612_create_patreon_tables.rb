# frozen_string_literal: true

class CreatePatreonTables < ActiveRecord::Migration[7.2]
  def change
    create_table :patreon_rewards do |t|
      t.string :patreon_id, null: false, limit: 255
      t.string :title, null: false, limit: 255
      t.integer :amount_cents, null: false, default: 0
      t.timestamps
    end
    add_index :patreon_rewards, :patreon_id, unique: true

    create_table :patreon_patrons do |t|
      t.string :patreon_id, null: false, limit: 255
      t.string :email, limit: 255
      t.integer :amount_cents
      t.datetime :declined_since
      t.timestamps
    end
    add_index :patreon_patrons, :patreon_id, unique: true
    add_index :patreon_patrons, :email

    create_table :patreon_patron_rewards do |t|
      t.references :patreon_patron, null: false, foreign_key: { on_delete: :cascade }
      t.references :patreon_reward, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
    end
    add_index :patreon_patron_rewards,
              %i[patreon_patron_id patreon_reward_id],
              unique: true,
              name: "idx_patreon_patron_rewards_unique"

    create_table :patreon_group_reward_filters do |t|
      t.references :group, null: false, foreign_key: { on_delete: :cascade }
      t.references :patreon_reward, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
    end
    add_index :patreon_group_reward_filters,
              %i[group_id patreon_reward_id],
              unique: true,
              name: "idx_patreon_group_reward_filters_unique"

    create_table :patreon_sync_logs do |t|
      t.datetime :synced_at, null: false
      t.timestamps
    end
    add_index :patreon_sync_logs, :synced_at
  end
end

# frozen_string_literal: true

class MigratePostPolicyTable < ActiveRecord::Migration[5.2]
  def up
    create_table(:post_policies) do |t|
      t.bigint :post_id, null: false, unique: true
      t.timestamp :renew_start
      t.integer :renew_days
      t.datetime :next_renew_at
      t.string :reminder
      t.datetime :last_reminded_at
      t.string :version
      t.integer :group_id, null: false
      t.timestamps
    end
  end

  def down
    drop_table :post_policies
  end
end

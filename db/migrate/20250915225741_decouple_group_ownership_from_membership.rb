# frozen_string_literal: true

class DecoupleGroupOwnershipFromMembership < ActiveRecord::Migration[8.0]
  def up
    create_table :group_owners do |t|
      t.integer :group_id, null: false
      t.integer :user_id, null: false
      t.timestamps null: false
    end

    add_index :group_owners, %i[group_id user_id], unique: true
    add_index :group_owners, %i[user_id group_id], unique: true

    execute <<~SQL
      INSERT INTO group_owners (group_id, user_id, created_at, updated_at)
      SELECT group_id, user_id, created_at, updated_at
      FROM group_users
      WHERE owner = true
    SQL
  end

  def down
    add_column :group_users, :owner, :boolean, null: false, default: false

    execute <<~SQL
      UPDATE group_users
      SET owner = true
      WHERE (group_id, user_id) IN (
        SELECT group_id, user_id FROM group_owners
      )
    SQL

    drop_table :group_owners
  end
end

# frozen_string_literal: true

class DecoupleGroupOwnershipFromMembership < ActiveRecord::Migration[8.0]
  def up
    # Create a new table for group ownership separate from membership
    create_table :group_owners do |t|
      t.integer :group_id, null: false
      t.integer :user_id, null: false
      t.timestamps null: false
    end

    add_index :group_owners, [:group_id, :user_id], unique: true
    add_index :group_owners, [:user_id, :group_id], unique: true

    # Add foreign key constraints
    add_foreign_key :group_owners, :groups, column: :group_id, on_delete: :cascade
    add_foreign_key :group_owners, :users, column: :user_id, on_delete: :cascade

    # Migrate existing owners to the new table
    # All current owners become both owners and members (preserving existing behavior)
    execute <<~SQL
      INSERT INTO group_owners (group_id, user_id, created_at, updated_at)
      SELECT group_id, user_id, created_at, updated_at
      FROM group_users
      WHERE owner = true
    SQL

    # Mark the owner column as ignored for now - will be removed in post-deployment migration
    # remove_column :group_users, :owner
  end

  def down
    # Add back the owner column
    add_column :group_users, :owner, :boolean, null: false, default: false

    # Migrate data back from group_owners to group_users
    execute <<~SQL
      UPDATE group_users
      SET owner = true
      WHERE (group_id, user_id) IN (
        SELECT group_id, user_id FROM group_owners
      )
    SQL

    # Drop the group_owners table
    drop_table :group_owners
  end
end
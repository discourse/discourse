# frozen_string_literal: true
class AddPostPolicyGroup < ActiveRecord::Migration[6.1]
  def up
    create_table(:post_policy_groups) do |t|
      t.integer :group_id, null: false
      t.bigint :post_policy_id, null: false
      t.timestamps
    end

    add_index :post_policy_groups, %i[post_policy_id group_id], unique: true

    execute <<~SQL
      INSERT INTO post_policy_groups(group_id, post_policy_id, created_at, updated_at)
      SELECT group_id, id, created_at, updated_at
      FROM post_policies
    SQL

    Migration::ColumnDropper.mark_readonly(:post_policies, :group_id)
  end

  def down
    drop_table :post_policy_groups
    Migration::ColumnDropper.drop_readonly(:post_policies, :group_id)
  end
end

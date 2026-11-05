# frozen_string_literal: true
class PrepareMultipleTopicAssignments < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    remove_index :assignments,
                 name: "index_assignments_on_post_target",
                 if_exists: true,
                 algorithm: :concurrently
    add_index :assignments,
              %i[target_id target_type],
              unique: true,
              where: "target_type = 'Post'",
              name: "index_assignments_on_post_target",
              algorithm: :concurrently
    remove_index :assignments,
                 name: "index_assignments_on_topic_group",
                 if_exists: true,
                 algorithm: :concurrently
    add_index :assignments,
              %i[target_id target_type],
              unique: true,
              where: "target_type = 'Topic' AND assigned_to_type = 'Group'",
              name: "index_assignments_on_topic_group",
              algorithm: :concurrently
    remove_index :assignments,
                 name: "index_assignments_on_target",
                 if_exists: true,
                 algorithm: :concurrently
    add_index :assignments,
              %i[target_id target_type],
              name: "index_assignments_on_target",
              algorithm: :concurrently
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

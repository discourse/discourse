# frozen_string_literal: true
class EnableMultipleTopicAssignments < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    remove_index :assignments,
                 name: "index_assignments_on_target_id_and_target_type",
                 if_exists: true,
                 algorithm: :concurrently
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

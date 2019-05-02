# frozen_string_literal: true

class FixIndexOnPostAction < ActiveRecord::Migration[4.2]
  def change
    remove_index "post_actions", name: "idx_unique_actions"
    add_index "post_actions", ["user_id", "post_action_type_id", "post_id", "deleted_at", "targets_topic"], name: "idx_unique_actions", unique: true
  end
end

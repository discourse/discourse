class FixPostActionsIndexAgain < ActiveRecord::Migration[4.2]
  def change
    remove_index "post_actions", name: "idx_unique_actions"
    add_index "post_actions",
                ["user_id", "post_action_type_id",
                 "post_id", "targets_topic"],
                name: "idx_unique_actions",
                unique: true,
                where: 'deleted_at IS NULL AND disagreed_at IS NULL AND deferred_at IS NULL'
  end
end

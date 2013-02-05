class CorrectIndexOnPostAction < ActiveRecord::Migration
  def change
    remove_index "post_actions", name: "idx_unique_actions"
    add_index "post_actions", ["user_id", "post_action_type_id", "post_id", "deleted_at"], name: "idx_unique_actions", unique: true
  end
end

class AddUniqueConstraintToUserActions < ActiveRecord::Migration
  def change
    add_index :user_actions, ['action_type','user_id', 'target_forum_thread_id', 'target_post_id', 'acting_user_id'], name: "idx_unique_rows", unique: true
  end
end

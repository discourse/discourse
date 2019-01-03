class DropQueuedPostIdFromUserActions < ActiveRecord::Migration[5.2]
  def up
    remove_column :user_actions, :queued_post_id
  end

  def down
    add_column :user_actions, :queued_post_id, :integer
  end
end

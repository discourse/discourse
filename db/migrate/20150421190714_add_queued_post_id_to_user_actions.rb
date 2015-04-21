class AddQueuedPostIdToUserActions < ActiveRecord::Migration
  def change
    add_column :user_actions, :queued_post_id, :integer, null: true
  end
end

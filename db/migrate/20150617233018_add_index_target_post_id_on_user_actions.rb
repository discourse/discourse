class AddIndexTargetPostIdOnUserActions < ActiveRecord::Migration[4.2]
  def change
    add_index :user_actions, %i[target_post_id]
  end
end

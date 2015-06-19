class AddIndexTargetPostIdOnUserActions < ActiveRecord::Migration
  def change
    add_index :user_actions, [:target_post_id]
  end
end

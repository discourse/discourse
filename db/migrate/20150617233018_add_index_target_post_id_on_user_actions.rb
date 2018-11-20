class AddIndexTargetPostIdOnUserActions < ActiveRecord::Migration[4.2]
  def change
    add_index :user_actions, [:target_post_id]
  end
end

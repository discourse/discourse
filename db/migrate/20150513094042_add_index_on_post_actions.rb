class AddIndexOnPostActions < ActiveRecord::Migration
  def change
    add_index :post_actions, [:user_id, :post_action_type_id], where: 'deleted_at IS NULL'
  end
end

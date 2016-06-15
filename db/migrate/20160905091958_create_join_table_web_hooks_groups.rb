class CreateJoinTableWebHooksGroups < ActiveRecord::Migration
  def change
    create_join_table :web_hooks, :groups
    add_index :groups_web_hooks, [:web_hook_id, :group_id], unique: true
  end
end

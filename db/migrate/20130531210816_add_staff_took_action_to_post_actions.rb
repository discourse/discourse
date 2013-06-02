class AddStaffTookActionToPostActions < ActiveRecord::Migration
  def change
    add_column :post_actions, :staff_took_action, :boolean, default: false, null: false
  end
end

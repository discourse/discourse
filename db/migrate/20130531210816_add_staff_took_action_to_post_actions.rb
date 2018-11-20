class AddStaffTookActionToPostActions < ActiveRecord::Migration[4.2]
  def change
    add_column :post_actions, :staff_took_action, :boolean, default: false, null: false
  end
end

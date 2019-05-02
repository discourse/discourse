# frozen_string_literal: true

class AddFilterIndexesToStaffActionLogs < ActiveRecord::Migration[4.2]
  def change
    add_index :staff_action_logs, [:action, :id]
    add_index :staff_action_logs, [:staff_user_id, :id]
    add_index :staff_action_logs, [:target_user_id, :id]
  end
end

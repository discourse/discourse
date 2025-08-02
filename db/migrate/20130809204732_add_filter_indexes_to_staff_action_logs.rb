# frozen_string_literal: true

class AddFilterIndexesToStaffActionLogs < ActiveRecord::Migration[4.2]
  def change
    add_index :staff_action_logs, %i[action id]
    add_index :staff_action_logs, %i[staff_user_id id]
    add_index :staff_action_logs, %i[target_user_id id]
  end
end

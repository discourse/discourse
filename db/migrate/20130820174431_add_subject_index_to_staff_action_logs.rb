class AddSubjectIndexToStaffActionLogs < ActiveRecord::Migration
  def change
    add_index :staff_action_logs, [:subject, :id]
  end
end

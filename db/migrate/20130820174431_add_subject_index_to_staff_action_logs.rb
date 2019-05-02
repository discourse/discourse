# frozen_string_literal: true

class AddSubjectIndexToStaffActionLogs < ActiveRecord::Migration[4.2]
  def change
    add_index :staff_action_logs, [:subject, :id]
  end
end

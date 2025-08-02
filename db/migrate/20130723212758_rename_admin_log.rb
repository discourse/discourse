# frozen_string_literal: true

class RenameAdminLog < ActiveRecord::Migration[4.2]
  def up
    rename_table :admin_logs, :staff_action_logs
    rename_column :staff_action_logs, :admin_id, :staff_user_id
  end

  def down
    rename_table :staff_action_logs, :admin_logs
    rename_column :admin_logs, :staff_user_id, :admin_id
  end
end

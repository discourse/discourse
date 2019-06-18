# frozen_string_literal: true

class RenameStaffActionLogsToUserHistory < ActiveRecord::Migration[4.2]
  def up
    remove_index :staff_action_logs, [:staff_user_id, :id]
    rename_table :staff_action_logs, :user_histories
    rename_column :user_histories, :staff_user_id, :acting_user_id
    add_index :user_histories, [:acting_user_id, :action, :id]
  end

  def down
    remove_index :user_histories, [:acting_user_id, :action, :id]
    rename_table :user_histories, :staff_action_logs
    rename_column :staff_action_logs, :acting_user_id, :staff_user_id
    add_index :staff_action_logs, [:staff_user_id, :id]
  end
end

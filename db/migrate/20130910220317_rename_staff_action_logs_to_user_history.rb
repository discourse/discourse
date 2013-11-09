class RenameStaffActionLogsToUserHistory < ActiveRecord::Migration
  def up
    remove_index :staff_action_logs, [:staff_user_id, :id]
    rename_table :staff_action_logs, :user_histories
    rename_column :user_histories, :staff_user_id, :acting_user_id
    execute "ALTER INDEX staff_action_logs_pkey RENAME TO user_histories_pkey"
    add_index :user_histories, [:acting_user_id, :action, :id]
  end

  def down
    remove_index :user_histories, [:acting_user_id, :action, :id]
    rename_table :user_histories, :staff_action_logs
    rename_column :staff_action_logs, :acting_user_id, :staff_user_id
    execute "ALTER INDEX user_histories_pkey RENAME TO staff_action_logs_pkey"
    add_index :staff_action_logs, [:staff_user_id, :id]
  end
end

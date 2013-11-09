class RenameStaffActionPk < ActiveRecord::Migration
  def up
    execute "ALTER INDEX admin_logs_pkey RENAME TO staff_action_logs_pkey"
  end

  def down
    execute "ALTER INDEX staff_action_logs_pkey RENAME TO admin_logs_pkey"
  end
end

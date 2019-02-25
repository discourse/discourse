class DropEmailLogsTable < ActiveRecord::Migration[5.2]
  def up
    drop_table :email_logs
    raise ActiveRecord::Rollback
  end

  def down
    raise "not tested"
  end
end

class DropTable < ActiveRecord::Migration[5.1]
  def up
    drop_table :email_logs
  end

  def down
    raise "not tested"
  end
end

class CreateAdminLogs < ActiveRecord::Migration
  def up
    create_table :admin_logs, force: true do |t|
      t.integer :action,          null: false
      t.integer :admin_id,        null: false
      t.integer :target_user_id
      t.text    :details
      t.timestamps
    end
  end

  def down
    drop_table :admin_logs
  end
end

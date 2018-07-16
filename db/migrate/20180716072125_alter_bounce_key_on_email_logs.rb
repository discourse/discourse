class AlterBounceKeyOnEmailLogs < ActiveRecord::Migration[5.2]
  def up
    change_column :email_logs, :bounce_key, 'uuid USING bounce_key::uuid'
  end

  def down
    change_column :email_logs, :bounce_key, :string
  end
end

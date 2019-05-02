class AddBounceKeyIndexOnEmailLogs < ActiveRecord::Migration[5.2]
  def change
    execute <<~SQL
      DELETE FROM email_logs l
      WHERE bounce_key IS NOT NULL
        AND id > (
          SELECT MIN(id)
          FROM email_logs l2
          WHERE l2.bounce_key = l.bounce_key
        )
    SQL
    add_index :email_logs, [:bounce_key], unique: true, where: 'bounce_key IS NOT NULL'
  end
end

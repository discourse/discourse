class FixEmailLogs < ActiveRecord::Migration[4.2]
  def up
    execute <<-SQL
      UPDATE email_logs
         SET user_id = u.id
        FROM email_logs el
   LEFT JOIN users u ON u.email = el.to_address
       WHERE email_logs.id = el.id
         AND email_logs.user_id IS NULL
         AND NOT email_logs.skipped
    SQL
  end

  def down
  end
end

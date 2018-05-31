class RemoveCensoredPatternSiteSetting < ActiveRecord::Migration[5.1]
  def up
    execute <<~SQL
      INSERT INTO user_histories
        (action, acting_user_id, subject, previous_value,
         new_value, admin_only, created_at, updated_at)
      SELECT 3, -1, 'censored_pattern', value, '', true, now(), now()
        FROM site_settings
       WHERE name = 'censored_pattern'
         AND value != ''
    SQL

    execute "DELETE FROM site_settings WHERE name = 'censored_pattern'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

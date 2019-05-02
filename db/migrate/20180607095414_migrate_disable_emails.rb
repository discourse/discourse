# frozen_string_literal: true

class MigrateDisableEmails < ActiveRecord::Migration[5.1]
  def up
    execute "UPDATE site_settings SET data_type = 7 WHERE name = 'disable_emails';"
    execute "UPDATE site_settings SET value = 'yes' WHERE value = 't' AND name = 'disable_emails';"
    execute "UPDATE site_settings SET value = 'no' WHERE value = 'f' AND name = 'disable_emails';"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

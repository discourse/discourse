# frozen_string_literal: true

class MigrateDefaultUserEmailOptions < ActiveRecord::Migration[5.2]
  def up
    # see UserOption.email_level_types
    # always = 0, only_while_away: 1, never: 2

    email_always = DB.query_single("SELECT value FROM site_settings WHERE name = 'default_email_always'").first
    email_direct = DB.query_single("SELECT value FROM site_settings WHERE name = 'default_email_direct'").first
    email_personal_messages = DB.query_single("SELECT value FROM site_settings WHERE name = 'default_email_personal_messages'").first

    default_email_level = nil
    default_email_level = 0 if email_direct != 'f' && email_always == 't'
    default_email_level = 2 if email_direct == 'f'

    unless default_email_level.nil?
      execute "INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
                VALUES ('default_email_level', 7, #{default_email_level}, now(), now())"
    end

    default_email_messages_level = nil
    default_email_messages_level = 0 if email_personal_messages != 'f' && email_always == 't'
    default_email_messages_level = 2 if email_personal_messages == 'f'

    unless default_email_messages_level.nil?
      execute "INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
                VALUES ('default_email_messages_level', 7, #{default_email_messages_level}, now(), now())"
    end

    execute "DELETE from site_settings where name in ('default_email_always', 'default_email_direct', 'default_email_personal_messages')"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

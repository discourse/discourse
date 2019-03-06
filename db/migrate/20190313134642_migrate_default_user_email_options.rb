class MigrateDefaultUserEmailOptions < ActiveRecord::Migration[5.2]
  def up
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
    default_email_level = DB.query_single("SELECT value::int FROM site_settings WHERE name = 'default_email_level'").first
    default_email_messages_level = DB.query_single("SELECT value::int FROM site_settings WHERE name = 'default_email_messages_level'").first

    if default_email_level == 0
      execute "INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
                VALUES ('default_email_always', 5, 't', now(), now())"
    elsif default_email_level == 2
      execute "INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
                VALUES ('default_email_direct', 5, 'f', now(), now())"
    end

    if default_email_messages_level == 0
      execute "INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
                VALUES ('default_email_always', 5, 't', now(), now())"
    elsif default_email_messages_level == 2
      execute "INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
                VALUES ('default_email_personal_messages', 5, 'f', now(), now())"
    end

    execute "DELETE from site_settings where name in ('default_email_messages_level', 'default_email_level')"
  end
end

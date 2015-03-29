class DisableExternalAuthsByDefault < ActiveRecord::Migration

  def enable_setting_if_default(name)
    result = User.exec_sql("SELECT count(*) count FROM site_settings WHERE name = '#{name}'")
    if result[0]['count'].to_i == 0
      execute "INSERT INTO site_settings (name, data_type, value, created_at, updated_at) VALUES ('#{name}', 5, 't', now(), now())"
    end
  end

  def up
    users_count_query = User.exec_sql("SELECT count(*) FROM users")
    if users_count_query[0]['count'].to_i > 1
      # existing site, so keep settings as they are
      enable_setting_if_default 'enable_yahoo_logins'
      enable_setting_if_default 'enable_google_oauth2_logins'
      enable_setting_if_default 'enable_twitter_logins'
      enable_setting_if_default 'enable_facebook_logins'
    end
  end

  def down
    # No need to undo
  end
end

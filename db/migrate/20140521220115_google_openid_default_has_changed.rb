class GoogleOpenidDefaultHasChanged < ActiveRecord::Migration[4.2]
  def up
    users_count_query = DB.query_single("SELECT count(*) FROM users")
    if users_count_query.first.to_i > 1
      # This is an existing site.
      result = DB.query_single("SELECT count(*) FROM site_settings WHERE name = 'enable_google_logins'")
      if result.first.to_i == 0
        # The old default was true, so add a row to keep it that way.
        execute "INSERT INTO site_settings (name, data_type, value, created_at, updated_at) VALUES ('enable_google_logins', 5, 't', now(), now())"
      end

      # Don't enable the new Google setting on an existing site.
      result = DB.query_single("SELECT count(*) FROM site_settings WHERE name = 'enable_google_oauth2_logins'")
      if result.first.to_i == 0
        execute "INSERT INTO site_settings (name, data_type, value, created_at, updated_at) VALUES ('enable_google_oauth2_logins', 5, 'f', now(), now())"
      end
    end
  end

  def down
    # No need to undo.
  end
end

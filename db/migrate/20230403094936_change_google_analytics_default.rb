# frozen_string_literal: true

class ChangeGoogleAnalyticsDefault < ActiveRecord::Migration[7.0]
  def up
    should_persist_old_default =
      Migration::Helpers.existing_site? && tracking_code && current_db_version != "v4_gtag"

    return if !should_persist_old_default

    execute <<~SQL
      INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
      VALUES ('ga_version', 7, 'v3_analytics', now(), now())
      ON CONFLICT DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  def tracking_code
    DB.query_single("SELECT value FROM site_settings WHERE name='ga_universal_tracking_code'")[
      0
    ].presence
  end

  def current_db_version
    DB.query_single("SELECT value FROM site_settings WHERE name='ga_version'")[0].presence
  end
end

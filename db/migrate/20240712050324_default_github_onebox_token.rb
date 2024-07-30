# frozen_string_literal: true

class DefaultGithubOneboxToken < ActiveRecord::Migration[7.1]
  def up
    existing_token =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'github_onebox_access_token'",
      ).first

    # 8 is the data type for a list
    execute <<~SQL if existing_token.present?
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      VALUES ('github_onebox_access_tokens', 8, 'default|#{existing_token}', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ON CONFLICT DO NOTHING
    SQL

    execute <<~SQL
      DELETE FROM site_settings WHERE name = 'github_onebox_access_token'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

# frozen_string_literal: true

class SetUseEmailForUsernameAndNameSuggestionsOnExistingSites < ActiveRecord::Migration[6.1]
  def up
    result = execute <<~SQL
      SELECT created_at
      FROM schema_migration_details
      ORDER BY created_at
      LIMIT 1
    SQL

    # make setting enabled for existing sites
    if result.first['created_at'].to_datetime < 1.hour.ago
      execute <<~SQL
        INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
        VALUES('use_email_for_username_and_name_suggestions', 5, 't', NOW(), NOW())
        ON CONFLICT (name) DO NOTHING
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

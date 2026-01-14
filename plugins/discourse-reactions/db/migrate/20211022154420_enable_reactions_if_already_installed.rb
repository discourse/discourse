# frozen_string_literal: true

class EnableReactionsIfAlreadyInstalled < ActiveRecord::Migration[6.1]
  def up
    reactions_installed_at = DB.query_single(<<~SQL)&.first
      SELECT created_at FROM schema_migration_details WHERE version='20201217062301'
    SQL

    if reactions_installed_at && reactions_installed_at < Date.new(2021, 10, 21)
      # The plugin was installed before we changed it to be disabled-by-default
      # Therefore, if there is no existing database value, enable the plugin
      execute <<~SQL
        INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
        VALUES('discourse_reactions_enabled', 5, 't', NOW(), NOW())
        ON CONFLICT (name) DO NOTHING
      SQL
    end
  end

  def down
    # do nothing
  end
end

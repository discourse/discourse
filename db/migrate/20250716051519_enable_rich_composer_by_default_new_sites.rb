# frozen_string_literal: true
class EnableRichComposerByDefaultNewSites < ActiveRecord::Migration[7.2]
  def change
    return if !Migration::Helpers.existing_site?

    current_val =
      DB.query_single("SELECT value FROM site_settings WHERE name = 'rich_editor'").first

    # We don't want to change whatever the admin already put in the DB
    return if !current_val.nil?

    # Set the old default value in the DB
    # 5 is bool type
    execute <<~SQL
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      VALUES ('rich_editor', 5, 'f', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

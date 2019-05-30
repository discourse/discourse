# frozen_string_literal: true

class DropKeyColumnFromThemes < ActiveRecord::Migration[5.2]
  def up
    add_column :user_options, :theme_ids, :integer, array: true,  null: false, default: []

    execute(
      "UPDATE user_options AS uo
       SET theme_ids = (
         SELECT array_agg(themes.id)
         FROM themes
         INNER JOIN user_options
         ON themes.key = user_options.theme_key
         WHERE user_options.user_id = uo.user_id
       ) WHERE uo.theme_key IN (SELECT key FROM themes)"
    )

    execute(
      "INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
       SELECT 'default_theme_id', 3, id, now(), now()
         FROM themes
       WHERE key = (SELECT value FROM site_settings WHERE name = 'default_theme_key')"
    )

    execute("DELETE FROM site_settings WHERE name = 'default_theme_key'")

    # delayed drop for theme_key on user_options table
    # delayed drop for key on themes table
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

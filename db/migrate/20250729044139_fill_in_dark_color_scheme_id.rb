# frozen_string_literal: true
class FillInDarkColorSchemeId < ActiveRecord::Migration[8.0]
  def up
    dark_scheme_id =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'default_dark_mode_color_scheme_id' LIMIT 1",
      ).first

    return if !dark_scheme_id
    execute "DELETE from site_settings where name = 'default_dark_mode_color_scheme_id'"
    if DB.query_single("SELECT 1 FROM color_schemes WHERE id = #{dark_scheme_id}").first.blank?
      return
    end
    execute <<~SQL
        UPDATE themes
        SET dark_color_scheme_id = #{dark_scheme_id}
        WHERE dark_color_scheme_id IS NULL
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

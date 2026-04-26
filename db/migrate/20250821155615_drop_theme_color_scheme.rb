# frozen_string_literal: true

class DropThemeColorScheme < ActiveRecord::Migration[8.0]
  DROPPED_TABLES = %i[theme_color_schemes]

  def up
    delete_ids = DB.query_single("SELECT color_scheme_id FROM theme_color_schemes")

    if delete_ids.length > 0
      execute("DELETE FROM color_schemes WHERE id IN (#{delete_ids.join(",")})")
      execute("DELETE FROM color_scheme_colors WHERE color_scheme_id IN (#{delete_ids.join(",")})")
    end

    DROPPED_TABLES.each { |table| Migration::TableDropper.execute_drop(table) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

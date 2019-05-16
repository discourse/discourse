# frozen_string_literal: true

class AddComponentToThemes < ActiveRecord::Migration[5.2]
  def up
    add_column :themes, :component, :boolean, null: false, default: false

    execute("
      UPDATE themes
      SET component = true, color_scheme_id = NULL, user_selectable = false
      WHERE id IN (SELECT child_theme_id FROM child_themes)
    ")

    execute("
      UPDATE site_settings
      SET value = -1
      WHERE name = 'default_theme_id' AND value::integer IN (SELECT id FROM themes WHERE component)
    ")

    execute("
      DELETE FROM child_themes
      WHERE parent_theme_id IN (SELECT id FROM themes WHERE component)
    ")
  end

  def down
    remove_column :themes, :component
  end
end

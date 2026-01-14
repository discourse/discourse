# frozen_string_literal: true

class RemoveUseOverhauledThemeColorPaletteSetting < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM site_settings WHERE name = 'use_overhauled_theme_color_palette'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

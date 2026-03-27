# frozen_string_literal: true
class AddLimitColorSchemesToThemeModifier < ActiveRecord::Migration[8.0]
  def change
    add_column :theme_modifier_sets, :only_theme_color_schemes, :boolean, null: true
  end
end

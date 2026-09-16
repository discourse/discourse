# frozen_string_literal: true
class AddDuplicableThemeToThemeModifierSets < ActiveRecord::Migration[8.0]
  def change
    # Theme modifier (auto-registered from this column by ThemeModifierSet).
    # NULL = duplicable (the default); a theme sets it `false` in about.json
    # `modifiers:` to forbid the block-layout editor from duplicating it.
    add_column :theme_modifier_sets, :duplicable_theme, :boolean
  end
end

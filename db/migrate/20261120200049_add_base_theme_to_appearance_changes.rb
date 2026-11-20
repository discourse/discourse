# frozen_string_literal: true

class AddBaseThemeToAppearanceChanges < ActiveRecord::Migration[8.1]
  def change
    add_column :appearance_changes, :base_theme_id, :integer
    add_index :appearance_changes, :base_theme_id
  end
end

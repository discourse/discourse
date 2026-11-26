# frozen_string_literal: true

class AddParentThemeToAppearanceChanges < ActiveRecord::Migration[8.1]
  def change
    add_column :appearance_changes, :parent_theme_id, :integer
    add_index :appearance_changes, :parent_theme_id
  end
end

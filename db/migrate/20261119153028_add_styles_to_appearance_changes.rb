# frozen_string_literal: true

class AddStylesToAppearanceChanges < ActiveRecord::Migration[8.1]
  def change
    add_column :appearance_changes, :styles, :jsonb, null: false, default: {}
    add_column :appearance_changes, :css, :text, null: false, default: ""
    add_column :appearance_changes, :replaces_theme_id, :integer
  end
end

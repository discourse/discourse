# frozen_string_literal: true

class AllowAppearanceChangesWithoutPalettes < ActiveRecord::Migration[8.1]
  def change
    change_column_null :appearance_changes, :light_color_scheme_id, true
    change_column_null :appearance_changes, :dark_color_scheme_id, true
  end
end

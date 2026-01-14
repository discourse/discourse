# frozen_string_literal: true
class AddDarkColorSchemeIdToThemes < ActiveRecord::Migration[7.2]
  def change
    add_column :themes, :dark_color_scheme_id, :integer, default: nil
  end
end

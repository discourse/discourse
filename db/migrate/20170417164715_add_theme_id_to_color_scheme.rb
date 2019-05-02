# frozen_string_literal: true

class AddThemeIdToColorScheme < ActiveRecord::Migration[4.2]
  def change
    add_column :color_schemes, :theme_id, :int
  end
end

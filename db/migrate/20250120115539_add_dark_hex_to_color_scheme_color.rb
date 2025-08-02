# frozen_string_literal: true

class AddDarkHexToColorSchemeColor < ActiveRecord::Migration[7.2]
  def change
    add_column :color_scheme_colors, :dark_hex, :string, limit: 6
  end
end

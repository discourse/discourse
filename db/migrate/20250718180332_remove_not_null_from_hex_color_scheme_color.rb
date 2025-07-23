# frozen_string_literal: true

class RemoveNotNullFromHexColorSchemeColor < ActiveRecord::Migration[7.2]
  def change
    change_column_null :color_scheme_colors, :hex, true
  end
end

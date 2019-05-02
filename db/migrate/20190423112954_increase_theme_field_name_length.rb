# frozen_string_literal: true

class IncreaseThemeFieldNameLength < ActiveRecord::Migration[5.2]
  def change
    change_column :theme_fields, :name, :string, limit: 255
  end
end

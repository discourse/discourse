# frozen_string_literal: true

class AddJsonValueToThemeSettings < ActiveRecord::Migration[7.0]
  def change
    add_column :theme_settings, :json_value, :jsonb
  end
end

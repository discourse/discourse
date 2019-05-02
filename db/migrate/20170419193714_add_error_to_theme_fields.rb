# frozen_string_literal: true

class AddErrorToThemeFields < ActiveRecord::Migration[4.2]
  def change
    add_column :theme_fields, :error, :string
  end
end

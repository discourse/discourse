# frozen_string_literal: true

class AddDarkModeBackgroundToCategories < ActiveRecord::Migration[7.0]
  def change
    add_column :categories, :uploaded_background_dark_id, :integer, index: true
  end
end

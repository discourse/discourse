# frozen_string_literal: true

class AddDarkModeLogoToCategories < ActiveRecord::Migration[7.0]
  def change
    add_column :categories, :uploaded_logo_dark_id, :integer, index: true
  end
end

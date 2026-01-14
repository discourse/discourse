# frozen_string_literal: true

class AddLocaleToCategories < ActiveRecord::Migration[7.2]
  def change
    add_column :categories, :locale, :string, limit: 20
  end
end

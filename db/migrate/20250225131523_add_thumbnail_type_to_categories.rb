# frozen_string_literal: true
class AddThumbnailTypeToCategories < ActiveRecord::Migration[7.2]
  def change
    add_column :categories, :thumbnail_type, :integer, default: 0, null: false
    add_column :categories, :thumbnail_value, :string, default: "", null: false
  end
end

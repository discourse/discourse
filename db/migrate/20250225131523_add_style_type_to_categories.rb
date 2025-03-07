# frozen_string_literal: true
class AddStyleTypeToCategories < ActiveRecord::Migration[7.2]
  def change
    add_column :categories, :style_type, :integer, default: 0, null: false
    add_column :categories, :style_emoji, :string, default: ""
    add_column :categories, :style_icon, :string, default: ""
  end
end

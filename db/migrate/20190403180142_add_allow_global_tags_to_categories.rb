# frozen_string_literal: true

class AddAllowGlobalTagsToCategories < ActiveRecord::Migration[5.2]
  def change
    add_column :categories, :allow_global_tags, :boolean, default: false, null: false
  end
end

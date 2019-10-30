# frozen_string_literal: true

class AddRequiredTagGroupToCategories < ActiveRecord::Migration[6.0]
  def change
    add_column :categories, :required_tag_group_id, :integer, null: true
    add_column :categories, :min_tags_from_required_group, :integer, null: false, default: 1
  end
end

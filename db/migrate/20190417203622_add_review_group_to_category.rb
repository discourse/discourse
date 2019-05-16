# frozen_string_literal: true

class AddReviewGroupToCategory < ActiveRecord::Migration[5.2]
  def change
    add_column :categories, :reviewable_by_group_id, :integer, null: true
    add_index :categories, :reviewable_by_group_id
    add_index :reviewables, :reviewable_by_group_id
  end
end

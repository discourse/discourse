# frozen_string_literal: true

class AddCategoryIndexToSharedDrafts < ActiveRecord::Migration[5.1]
  def change
    add_index :shared_drafts, :category_id
  end
end

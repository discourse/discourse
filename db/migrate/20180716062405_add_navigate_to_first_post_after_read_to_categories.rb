# frozen_string_literal: true

class AddNavigateToFirstPostAfterReadToCategories < ActiveRecord::Migration[5.2]
  def change
    add_column :categories, :navigate_to_first_post_after_read, :bool, null: false, default: false
  end
end

# frozen_string_literal: true

class AddAutoCloseBasedOnLastPostToCategories < ActiveRecord::Migration[4.2]
  def change
    add_column :categories, :auto_close_based_on_last_post, :boolean, default: false
  end
end

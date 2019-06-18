# frozen_string_literal: true

class AddUserIdToCategories < ActiveRecord::Migration[4.2]
  def change
    add_column :categories, :user_id, :integer
    execute "UPDATE categories SET user_id = 1186"
    change_column :categories, :user_id, :integer, null: false
  end
end

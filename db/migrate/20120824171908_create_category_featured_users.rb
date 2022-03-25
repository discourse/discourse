# frozen_string_literal: true

class CreateCategoryFeaturedUsers < ActiveRecord::Migration[4.2]
  def change
    create_table :category_featured_users do |t|
      t.integer :category_id, null: false
      t.integer :user_id, null: false
      t.timestamps null: false
    end

    add_index :category_featured_users, [:category_id, :user_id], unique: true
  end
end

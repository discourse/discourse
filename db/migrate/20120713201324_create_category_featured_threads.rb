# frozen_string_literal: true

class CreateCategoryFeaturedThreads < ActiveRecord::Migration[4.2]
  def change
    create_table :category_featured_threads, id: false do |t|
      t.integer :category_id, null: false
      t.integer :forum_thread_id, null: false
      t.timestamps null: false
    end

    add_index :category_featured_threads, [:category_id, :forum_thread_id], unique: true, name: 'cat_featured_threads'
  end
end

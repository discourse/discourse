class CreateCategoryFeaturedThreads < ActiveRecord::Migration[4.2]
  def change
    create_table :category_featured_threads, id: false do |t|
      t.references :category, null: false
      t.references :forum_thread, null: false
      t.timestamps null: false
    end

    add_index :category_featured_threads, [:category_id, :forum_thread_id], unique: true, name: 'cat_featured_threads'
  end
end

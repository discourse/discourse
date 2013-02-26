class CreateCategories < ActiveRecord::Migration
  def up
    create_table :categories do |t|
      t.string :name, limit: 50, null: false
      t.string :color, limit: 6, null: false, default: 'AB9364'
      t.integer :forum_thread_id, null: true
      t.integer :top1_forum_thread_id, null: true
      t.integer :top2_forum_thread_id, null: true
      t.integer :top1_user_id, null: true
      t.integer :top2_user_id, null: true
      t.integer :forum_thread_count, null: false, default: 0
      t.timestamps
    end

    add_index :categories, :name, unique: true
    add_index :categories, :forum_thread_count

    execute "INSERT INTO categories (name, forum_thread_count, created_at, updated_At)
             SELECT tag, count(*), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP from forum_threads
             WHERE tag IS NOT NULL AND tag <> 'null'
             GROUP BY tag"
  end

  def down
    drop_table :categories
  end

end

class CreateUploads < ActiveRecord::Migration[4.2]
  def change
    create_table :uploads do |t|
      t.integer :user_id, null: false
      t.integer :forum_thread_id, null: false
      t.string  :original_filename, null: false
      t.integer :filesize, null: false
      t.integer :width, null: true
      t.integer :height, null: true
      t.string  :url, null: false
      t.timestamps null: false
    end

    add_index :uploads, :forum_thread_id
    add_index :uploads, :user_id
  end

end

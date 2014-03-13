class CreatePostMeta < ActiveRecord::Migration
  def up
    create_table :post_meta do |t|
      t.belongs_to :post
      t.boolean :client, default: false, null: false
      t.string :key, limit: 100, null: false
      t.text :value
    end
    
    add_index :post_meta, :key, unique: true
  end
  
  def down
    drop_table :post_meta
  end
end
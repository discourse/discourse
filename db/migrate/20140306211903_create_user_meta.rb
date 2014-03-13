class CreateUserMeta < ActiveRecord::Migration
  def up
    create_table :user_meta do |t|
      t.belongs_to :user
      t.boolean :client, default: false, null: false
      t.string :key, limit: 100, null: false
      t.text :value
    end
    
    add_index :user_meta, :key, unique: true
  end
  
  def down
    drop_table :user_meta
  end
end
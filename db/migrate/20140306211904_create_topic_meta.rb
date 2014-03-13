class CreateTopicMeta < ActiveRecord::Migration
  def up
    create_table :topic_meta do |t|
      t.belongs_to :topic
      t.boolean :client, default: false, null: false
      t.string :key, limit: 100, null: false
      t.text :value
    end
    
    add_index :topic_meta, :key, unique: true
  end
  
  def down
    drop_table :topic_meta
  end
end
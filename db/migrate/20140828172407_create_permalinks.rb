class CreatePermalinks < ActiveRecord::Migration
  def change
    create_table :permalinks do |t|
      t.string :url, null: false
      t.integer :topic_id
      t.integer :post_id
      t.integer :category_id

      t.timestamps
    end

    add_index :permalinks, :url
  end
end

class CreatePermalinks < ActiveRecord::Migration[4.2]
  def change
    create_table :permalinks do |t|
      t.string :url, null: false
      t.integer :topic_id
      t.integer :post_id
      t.integer :category_id

      t.timestamps null: false
    end

    add_index :permalinks, :url
  end
end

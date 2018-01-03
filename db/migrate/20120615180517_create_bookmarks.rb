class CreateBookmarks < ActiveRecord::Migration[4.2]
  def change
    create_table :bookmarks do |t|
      t.integer :user_id
      t.integer :post_id
      t.timestamps null: false
    end

    add_index :bookmarks, [:user_id, :post_id], unique: true
  end
end

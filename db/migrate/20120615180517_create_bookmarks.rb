class CreateBookmarks < ActiveRecord::Migration
  def change
    create_table :bookmarks do |t|
      t.integer :user_id
      t.integer :post_id
      t.timestamps
    end

    add_index :bookmarks, [:user_id, :post_id], unique: true
  end
end

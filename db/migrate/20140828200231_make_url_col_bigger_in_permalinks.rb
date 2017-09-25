class MakeUrlColBiggerInPermalinks < ActiveRecord::Migration[4.2]
  def up
    remove_index :permalinks, :url
    change_column :permalinks, :url, :string, limit: 1000, null: false
    add_index :permalinks, :url, unique: true
  end

  def down
  end
end

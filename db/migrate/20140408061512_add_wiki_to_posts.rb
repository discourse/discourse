class AddWikiToPosts < ActiveRecord::Migration[4.2]
  def change
    add_column :posts, :wiki, :boolean, default: false, null: false
  end
end

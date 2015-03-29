class AddWikiToPosts < ActiveRecord::Migration
  def change
    add_column :posts, :wiki, :boolean, default: false, null: false
  end
end

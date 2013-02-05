class CookedMigration < ActiveRecord::Migration
  def change
    rename_column :posts, :content, :raw
    rename_column :posts, :formatted_content, :cooked
  end
end

class RemoveCategoryHotness < ActiveRecord::Migration
  def change
    remove_column :categories, :hotness
  end
end

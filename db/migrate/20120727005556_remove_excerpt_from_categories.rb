class RemoveExcerptFromCategories < ActiveRecord::Migration
  def up
    remove_column :categories, :excerpt
  end

  def down
    add_column :categories, :excerpt, :string, limit: 250
  end
end

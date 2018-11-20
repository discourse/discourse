class RemoveExcerptFromCategories < ActiveRecord::Migration[4.2]
  def up
    remove_column :categories, :excerpt
  end

  def down
    add_column :categories, :excerpt, :string, limit: 250
  end
end

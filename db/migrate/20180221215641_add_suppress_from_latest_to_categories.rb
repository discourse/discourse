class AddSuppressFromLatestToCategories < ActiveRecord::Migration[5.1]
  def up
    add_column :categories, :suppress_from_latest, :boolean, default: false
    execute <<~SQL
      UPDATE categories SET suppress_from_latest = suppress_from_homepage
    SQL
  end
  def down
    raise "can not be removed"
  end
end

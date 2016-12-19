class RemoveUploadUrlsFromCategories < ActiveRecord::Migration
  def up
    %w{
      logo_url
      background_url
    }.each do |column|
      Category.exec_sql("ALTER TABLE categories DROP COLUMN IF EXISTS #{column}")
    end
  end

  def down
    add_column :categories, :logo_url, :string
    add_column :categories, :background_url, :string
  end
end

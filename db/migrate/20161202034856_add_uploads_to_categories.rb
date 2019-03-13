class AddUploadsToCategories < ActiveRecord::Migration[4.2]
  def up
    add_column :categories, :uploaded_logo_id, :integer, index: true
    add_column :categories, :uploaded_background_id, :integer, index: true

    execute <<~SQL
    UPDATE categories
    SET uploaded_logo_id = u.id
    FROM categories c
    LEFT JOIN uploads u ON u.url = c.logo_url
    WHERE u.url IS NOT NULL
    SQL

    execute <<~SQL
    UPDATE categories
    SET uploaded_background_id = u.id
    FROM categories c
    LEFT JOIN uploads u ON u.url = c.background_url
    WHERE u.url IS NOT NULL
    SQL
  end
end

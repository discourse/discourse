# frozen_string_literal: true

class AddUploadsToCategories < ActiveRecord::Migration[4.2]
  def up
    add_column :categories, :uploaded_logo_id, :integer, index: true
    add_column :categories, :uploaded_background_id, :integer, index: true

    execute <<~SQL
    UPDATE categories c1
    SET uploaded_logo_id = u.id
    FROM categories c2
    INNER JOIN uploads u ON u.url = c2.logo_url
    WHERE c1.id = c2.id
    SQL

    execute <<~SQL
    UPDATE categories c1
    SET uploaded_background_id = u.id
    FROM categories c2
    INNER JOIN uploads u ON u.url = c2.background_url
    WHERE c1.id = c2.id
    SQL
  end
end

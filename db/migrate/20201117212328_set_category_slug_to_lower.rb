# frozen_string_literal: true

class SetCategorySlugToLower < ActiveRecord::Migration[6.0]
  def up
    remove_index(:categories, name: 'unique_index_categories_on_slug')

    # Reset uncategorized category
    execute <<~SQL
      UPDATE categories
      SET slug = 'uncategorized'
      WHERE id = 1 AND
            LOWER(slug) IN (SELECT LOWER(slug)
                            FROM categories
                            GROUP BY LOWER(slug)
                            HAVING COUNT(*) > 1)
    SQL

    # Resolve duplicate slugs by replacing all mixed case slugs to
    # "ID-lower_case_slug".
    execute <<~SQL
      UPDATE categories
      SET slug = id || '-' || LOWER(slug)
      WHERE slug != LOWER(slug) AND
            LOWER(slug) IN (SELECT LOWER(slug)
                            FROM categories
                            GROUP BY LOWER(slug)
                            HAVING COUNT(*) > 1)
    SQL

    # Ensure all slugs are lowercase
    execute "UPDATE categories SET slug = LOWER(slug)"

    add_index(
      :categories,
      'COALESCE(parent_category_id, -1), LOWER(slug)',
      name: 'unique_index_categories_on_slug',
      where: "slug != ''",
      unique: true
    )
  end

  def down
    remove_index(:categories, name: 'unique_index_categories_on_slug')

    add_index(
      :categories,
      'COALESCE(parent_category_id, -1), slug',
      name: 'unique_index_categories_on_slug',
      where: "slug != ''",
      unique: true
    )
  end
end

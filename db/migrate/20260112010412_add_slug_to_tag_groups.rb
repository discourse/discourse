# frozen_string_literal: true

class AddSlugToTagGroups < ActiveRecord::Migration[8.0]
  def up
    add_column :tag_groups, :slug, :string, null: false, default: ""

    # Step 1: Generate initial slugs from names
    execute <<~SQL
      UPDATE tag_groups
      SET slug = TRIM(BOTH '-' FROM
        REGEXP_REPLACE(
          REGEXP_REPLACE(
            LOWER(TRIM(name)),
            '[^a-z0-9\\s-]+', '-', 'g'
          ),
          '[\\s-]+', '-', 'g'
        )
      )
    SQL

    # Step 2: For duplicate slugs, append the ID to make them unique
    execute <<~SQL
      UPDATE tag_groups tg
      SET slug = slug || '-' || id::text
      WHERE EXISTS (
        SELECT 1 FROM tag_groups tg2
        WHERE LOWER(tg2.slug) = LOWER(tg.slug)
          AND tg2.id < tg.id
      )
    SQL

    # Step 3: Add unique index now that all slugs are unique
    add_index :tag_groups,
              "LOWER(slug)",
              unique: true,
              where: "slug <> ''",
              name: "index_tag_groups_on_lower_slug"
  end

  def down
    remove_index :tag_groups, name: "index_tag_groups_on_lower_slug"
    remove_column :tag_groups, :slug
  end
end

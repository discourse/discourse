# frozen_string_literal: true

class AddSlugIndexesToTags < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    execute "DROP INDEX CONCURRENTLY IF EXISTS index_tags_on_lower_slug"
    execute "DROP INDEX CONCURRENTLY IF EXISTS index_tags_on_slug"

    add_index :tags,
              "lower(slug)",
              unique: true,
              name: "index_tags_on_lower_slug",
              where: "slug <> ''",
              algorithm: :concurrently
    add_index :tags, :slug, where: "slug <> ''", algorithm: :concurrently
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

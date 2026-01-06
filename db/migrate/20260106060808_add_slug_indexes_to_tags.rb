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
              algorithm: :concurrently
    add_index :tags, :slug, algorithm: :concurrently

    change_column_null :tags, :slug, false
  end

  def down
    remove_index :tags, name: "index_tags_on_lower_slug", if_exists: true
    remove_index :tags, :slug, if_exists: true

    change_column_null :tags, :slug, true
  end
end

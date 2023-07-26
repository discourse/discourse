# frozen_string_literal: true

class DeleteHotlinkedImageCustomFields < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    execute <<~SQL
      DELETE FROM post_custom_fields
      WHERE name IN (
        'downloaded_images',
        'broken_images',
        'large_images'
      )
    SQL

    execute <<~SQL
      DROP INDEX CONCURRENTLY IF EXISTS post_custom_field_broken_images_idx
    SQL

    execute <<~SQL
      DROP INDEX CONCURRENTLY IF EXISTS post_custom_field_downloaded_images_idx
    SQL

    execute <<~SQL
      DROP INDEX CONCURRENTLY IF EXISTS post_custom_field_large_images_idx
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

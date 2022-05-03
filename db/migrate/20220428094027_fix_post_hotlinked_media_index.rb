# frozen_string_literal: true

class FixPostHotlinkedMediaIndex < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def up
    execute <<~SQL
      CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS index_post_hotlinked_media_on_post_id_and_url_md5
      ON post_hotlinked_media (post_id, md5(url));
    SQL

    # Failed index introduced in 20220428094026_create_post_hotlinked_media. On some installations it succeeded,
    # so we need to clean it up.
    execute <<~SQL
      DROP INDEX CONCURRENTLY IF EXISTS index_post_hotlinked_media_on_post_id_and_url;
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

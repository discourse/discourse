# frozen_string_literal: true

class IndexUploadStorageDeduplication < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    remove_index :uploads, :primary_upload_id, algorithm: :concurrently, if_exists: true
    add_index :uploads, :primary_upload_id, algorithm: :concurrently

    remove_index :uploads,
                 name: "index_uploads_on_primary_lookup",
                 algorithm: :concurrently,
                 if_exists: true
    add_index :uploads,
              %i[original_sha1 secure],
              where: "primary_upload_id IS NULL AND original_sha1 IS NOT NULL",
              name: "index_uploads_on_primary_lookup",
              algorithm: :concurrently
  end

  def down
    remove_index :uploads,
                 name: "index_uploads_on_primary_lookup",
                 algorithm: :concurrently,
                 if_exists: true
    remove_index :uploads, :primary_upload_id, algorithm: :concurrently, if_exists: true
  end
end

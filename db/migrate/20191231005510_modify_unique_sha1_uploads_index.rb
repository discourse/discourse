# frozen_string_literal: true

class ModifyUniqueSha1UploadsIndex < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def up
    remove_index :uploads, :sha1 if index_exists?(:uploads, :sha1)
    execute <<~SQL
      CREATE UNIQUE INDEX CONCURRENTLY idx_uploads_on_sha1_for_nonsecure
      ON uploads(sha1)
      WHERE secure = FALSE
    SQL
  end

  def down
    create_index :uploads, :sha1, unique: true, algorithm: :concurrently
    remove_index(:uploads, name: "idx_uploads_on_sha1_for_nonsecure") if index_exists?("idx_uploads_on_sha1_for_nonsecure")
  end
end

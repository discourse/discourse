# frozen_string_literal: true

class AddPrimaryUploadIdToUploads < ActiveRecord::Migration[7.2]
  def change
    add_column :uploads, :primary_upload_id, :bigint, null: true

    add_index :uploads, :primary_upload_id

    # Partial index for fast primary lookups by original_sha1 and secure status
    add_index :uploads,
              %i[original_sha1 secure],
              where: "primary_upload_id IS NULL AND original_sha1 IS NOT NULL",
              name: "index_uploads_on_primary_lookup"

    # FK ensures DB-level integrity; SET NULL handles edge cases like raw SQL deletes
    add_foreign_key :uploads, :uploads, column: :primary_upload_id, on_delete: :nullify
  end
end

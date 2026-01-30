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
  end
end

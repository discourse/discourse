# frozen_string_literal: true

class AddPrimaryUploadIdToUploads < ActiveRecord::Migration[7.2]
  def change
    add_column :uploads, :primary_upload_id, :bigint, null: true

    add_foreign_key :uploads,
                    :uploads,
                    column: :primary_upload_id,
                    on_delete: :nullify,
                    validate: false
  end
end

# frozen_string_literal: true

class CopyCategoriesUploadsToUploadReferences < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      INSERT INTO upload_references(upload_id, target_type, target_id, created_at, updated_at)
      SELECT categories.uploaded_logo_id, 'Category', categories.id, uploads.created_at, uploads.updated_at
      FROM categories
      JOIN uploads ON uploads.id = categories.uploaded_logo_id
      WHERE categories.uploaded_logo_id IS NOT NULL
      ON CONFLICT DO NOTHING
    SQL

    execute <<~SQL
      INSERT INTO upload_references(upload_id, target_type, target_id, created_at, updated_at)
      SELECT categories.uploaded_background_id, 'Category', categories.id, uploads.created_at, uploads.updated_at
      FROM categories
      JOIN uploads ON uploads.id = categories.uploaded_background_id
      WHERE categories.uploaded_background_id IS NOT NULL
      ON CONFLICT DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

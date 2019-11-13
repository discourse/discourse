# frozen_string_literal: true

class AddSecureToUploads < ActiveRecord::Migration[5.2]
  def up
    add_column :uploads, :secure, :boolean, default: false, null: false

    prevent_anons_from_downloading_files = \
      DB.query_single("SELECT value FROM site_settings WHERE name = 'prevent_anons_from_downloading_files'").first == 't'

    if prevent_anons_from_downloading_files
      execute(
        <<-SQL
        UPDATE uploads SET secure = 't' WHERE id IN (
          SELECT DISTINCT(uploads.id) FROM uploads
          INNER JOIN post_uploads ON post_uploads.upload_id = uploads.id
          WHERE LOWER(original_filename) NOT SIMILAR TO '%\.(jpg|jpeg|png|gif|svg|ico)'
        )
        SQL
      )
    end
  end

  def down
    remove_column :uploads, :secure
  end
end

# frozen_string_literal: true

module Migrations::Importer::Steps
  class Uploads < ::Migrations::Importer::CopyStep
    depends_on :users
    store_mapped_ids true

    requires_set :existing_sha1s, "SELECT sha1 FROM uploads"

    column_names %i[
                   user_id
                   original_filename
                   filesize
                   width
                   height
                   url
                   created_at
                   updated_at
                   sha1
                   origin
                   retain_hours
                   extension
                   thumbnail_width
                   thumbnail_height
                   etag
                   secure
                   access_control_post_id
                   original_sha1
                   animated
                   verification_status
                   security_last_changed_at
                   security_last_changed_reason
                   dominant_color
                 ]

    total_rows_query <<~SQL, MappingType::UPLOADS
      SELECT COUNT(*)
      FROM files.uploads up
           LEFT JOIN mapped.ids mup ON up.id = mup.original_id AND mup.type = ?
      WHERE up.upload IS NOT NULL
        AND mup.original_id IS NULL
    SQL

    rows_query <<~SQL, MappingType::UPLOADS
      SELECT up.id, up.upload
      FROM files.uploads up
           LEFT JOIN mapped.ids mup ON up.id = mup.original_id AND mup.type = ?
      WHERE up.upload IS NOT NULL
        AND mup.original_id IS NULL
      ORDER BY up.ROWID
    SQL

    private

    def transform_row(row)
      upload = JSON.parse(row[:upload], symbolize_names: true)
      return nil unless @existing_sha1s.add?(upload[:sha1])

      upload[:original_id] = row[:id]
      upload.delete(:id)

      super(upload)
    end
  end
end

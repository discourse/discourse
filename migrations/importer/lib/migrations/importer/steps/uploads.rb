# frozen_string_literal: true

module Migrations
  module Importer
    module Steps
      class Uploads < CopyStep
        depends_on :users
        store_mapped_ids true

        # sha1 => id of an upload that already exists on the target site, so we
        # can reuse it instead of copying the same file again.
        requires_mapping :existing_sha1s, "SELECT sha1, id FROM uploads"

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
          FROM files.upload_results ur
               JOIN files.uploads u ON u.id = ur.upload_id
               LEFT JOIN mapped.ids mup ON ur.id = mup.original_id AND mup.type = ?1
          WHERE mup.original_id IS NULL
        SQL

        rows_query <<~SQL, MappingType::USERS, MappingType::UPLOADS, Discourse::SYSTEM_USER_ID
          SELECT ur.id                          AS original_id,
                 u.id                           AS staging_id,
                 COALESCE(mu.discourse_id, ?3)  AS user_id,
                 u.original_filename,
                 u.filesize,
                 u.width,
                 u.height,
                 u.url,
                 u.created_at,
                 u.sha1,
                 u.origin,
                 u.extension,
                 u.thumbnail_width,
                 u.thumbnail_height,
                 u.etag,
                 u.secure,
                 u.original_sha1,
                 u.animated,
                 u.verification_status,
                 u.security_last_changed_at,
                 u.security_last_changed_reason,
                 u.dominant_color
          FROM files.upload_results ur
               JOIN files.uploads u ON u.id = ur.upload_id
               JOIN upload_sources us ON us.id = ur.id
               LEFT JOIN mapped.ids mu ON us.user_id = mu.original_id AND mu.type = ?1
               LEFT JOIN mapped.ids mup ON ur.id = mup.original_id AND mup.type = ?2
          WHERE mup.original_id IS NULL
          ORDER BY u.id
        SQL

        def execute
          unless files_db_attached?
            notice("No files database configured; skipping upload import")
            return
          end

          super
        end

        private

        def setup
          # staging upload id (files.uploads.id) => the Discourse upload id it
          # ended up as. Files are deduplicated by sha1 when they are uploaded,
          # so several source ids can point at the same staging upload.
          @staging_upload_ids = {}
        end

        def transform_row(row)
          staging_id = row.delete(:staging_id)
          sha1 = row[:sha1]

          # An earlier source file already used this staging upload. Map this
          # source id to the Discourse upload we created for it and skip the
          # copy. Without this the mapping was lost and later references to the
          # deduplicated source ids resolved to NULL.
          if (discourse_id = @staging_upload_ids[staging_id])
            row[:id] = discourse_id
            return nil
          end

          # The same file already exists on the target site. Reuse it. We only
          # match on a real sha1 because it is nullable and NULLs are not equal.
          if sha1 && (discourse_id = @existing_sha1s[sha1])
            @staging_upload_ids[staging_id] = discourse_id
            row[:id] = discourse_id
            return nil
          end

          transformed = super
          discourse_id = transformed[:id]
          @staging_upload_ids[staging_id] = discourse_id
          @existing_sha1s[sha1] = discourse_id if sha1
          transformed
        end
      end
    end
  end
end

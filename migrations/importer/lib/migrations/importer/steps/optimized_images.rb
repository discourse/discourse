# frozen_string_literal: true

module Migrations
  module Importer
    module Steps
      # Optimized images are just resized copies of an upload. They are an
      # optimization, not source data: if they are missing, a rebake regenerates
      # them. We still copy them so the target site does not have to rebuild
      # every thumbnail right after an import.
      class OptimizedImages < CopyStep
        depends_on :uploads

        # Natural key of Discourse's unique index, used to avoid inserting an
        # optimized image that is already present on the target site.
        requires_set :existing_optimized_images,
                     "SELECT upload_id, width, height, extension FROM optimized_images"

        column_names %i[
                       sha1
                       extension
                       width
                       height
                       upload_id
                       url
                       filesize
                       etag
                       version
                       created_at
                       updated_at
                     ]

        total_rows_query <<~SQL, MappingType::UPLOADS
          SELECT COUNT(*)
          FROM files.optimized_images oi
          WHERE EXISTS (
            SELECT 1
            FROM files.upload_results ur
                 JOIN mapped.ids mu ON ur.id = mu.original_id AND mu.type = ?1
            WHERE ur.upload_id = oi.upload_id
          )
        SQL

        # Several source files can share one staging upload (sha1 dedup), so the
        # join fans out; DISTINCT collapses it back to one row per optimized
        # image because they all resolve to the same Discourse upload id.
        rows_query <<~SQL, MappingType::UPLOADS
          SELECT DISTINCT
                 mu.discourse_id AS upload_id,
                 oi.sha1,
                 oi.extension,
                 oi.width,
                 oi.height,
                 oi.url,
                 oi.filesize,
                 oi.etag,
                 oi.version,
                 oi.created_at
          FROM files.optimized_images oi
               JOIN files.upload_results ur ON ur.upload_id = oi.upload_id
               JOIN mapped.ids mu ON ur.id = mu.original_id AND mu.type = ?1
          ORDER BY mu.discourse_id
        SQL

        def execute
          unless files_db_attached?
            notice("No files database configured; skipping optimized image import")
            return
          end

          super
        end

        private

        def transform_row(row)
          if @existing_optimized_images.include?(
               row[:upload_id],
               row[:width],
               row[:height],
               row[:extension],
             )
            return nil
          end

          super
        end
      end
    end
  end
end

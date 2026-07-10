# frozen_string_literal: true

require "ostruct"

module Migrations
  module Importer
    module Uploads
      module Tasks
        # Verifies that every recorded upload still has its file in the store, and
        # removes the rows whose file has gone missing so a later run recreates
        # them. Read-only on the workers; the writer thread does the deletions.
        class Fixer < Base
          def title
            "Fixing missing uploads"
          end

          def max_count
            @max_count ||= files_db.query_value("SELECT COUNT(*) FROM uploads")
          end

          def before_run
            # `discourse_store.external?` never changes during a run, so resolve it
            # once instead of on every processed row.
            @external_store = discourse_store.external?
          end

          # The pipeline also passes `emit_result:` (for rows a task resolves up
          # front); the fixer resolves nothing early, so it is ignored. An
          # underscore-prefixed keyword would NOT do that — it renames the required
          # keyword and the pipeline's call raises ArgumentError.
          def produce(emit_work:, **)
            files_db.query("SELECT id AS upload_id, url FROM uploads ORDER BY id DESC") do |row|
              emit_work.call(row)
            end
          end

          def build_worker_resource
            OpenStruct.new(url: "", secure?: SiteSetting.secure_uploads, optimized_images: [])
          end

          def process(row, fake_upload)
            fake_upload.url = row[:url]
            path = add_multisite_prefix(discourse_store.get_path_for_upload(fake_upload))

            return { upload_id: row[:upload_id], status: :missing } unless file_exists?(path)

            # The file is still there. On an external store a fix_missing run
            # doubles as a repair pass for the upload's ACL and access-control tags.
            discourse_store.update_upload_access_control(fake_upload) if @external_store

            { upload_id: row[:upload_id], status: :ok }
          rescue StandardError => e
            { upload_id: row[:upload_id], status: :error, error: e.message }
          end

          def write(result)
            case result[:status]
            when :ok
              :ok
            when :missing
              remove_missing_upload(result[:upload_id])
              reporter.notice(I18n.t("importer.uploads.fixer_missing", id: result[:upload_id]))
              :warning
            else
              reporter.notice(
                I18n.t(
                  "importer.uploads.fixer_error",
                  id: result[:upload_id],
                  error: result[:error],
                ),
              )
              :error
            end
          end

          private

          # Drops the upload everywhere it's recorded — the Discourse record, the
          # staging row, its optimized images, and every result that points at it.
          # With the result rows gone, the uploader's incremental skip no longer
          # sees those source ids and recreates them on the next run.
          def remove_missing_upload(upload_id)
            Upload.delete_by(id: upload_id)
            files_db.execute("DELETE FROM optimized_images WHERE upload_id = ?", upload_id)
            files_db.execute("DELETE FROM uploads WHERE id = ?", upload_id)
            files_db.execute("DELETE FROM upload_results WHERE upload_id = ?", upload_id)
          end
        end
      end
    end
  end
end

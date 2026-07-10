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

          def produce(emit_work:, _emit_result:)
            files_db.query("SELECT id AS upload_id, url FROM uploads ORDER BY id DESC") do |row|
              emit_work.call(row)
            end
          end

          def build_worker_resource
            OpenStruct.new(url: "")
          end

          def process(row, fake_upload)
            fake_upload.url = row[:url]
            path = add_multisite_prefix(discourse_store.get_path_for_upload(fake_upload))

            status = file_exists?(path) ? :ok : :missing
            { upload_id: row[:upload_id], status: }
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

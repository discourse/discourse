# frozen_string_literal: true

require "ostruct"

module Migrations
  module Importer
    module Uploads
      module Tasks
        # Verifies that every recorded upload still has its file in the store, and
        # removes the rows whose file has gone missing so the following uploader
        # task recreates them. Read-only on the workers; the writer thread does the
        # deletions.
        class Fixer < Base
          ERROR_SAMPLE_SIZE = 5

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
            @missing_count = 0
            @error_count = 0
            @error_samples = []
          end

          def after_run
            super

            if @missing_count.positive?
              reporter.notice(
                I18n.t("importer.uploads.fixer_missing_summary", count: @missing_count),
              )
            end

            return if @error_count.zero?

            errors =
              @error_samples.map do |result|
                I18n.t(
                  "importer.uploads.fixer_error_detail",
                  id: result[:upload_id],
                  error: result[:error],
                )
              end
            reporter.notice(
              I18n.t(
                "importer.uploads.fixer_error_summary",
                count: @error_count,
                errors: errors.join("; "),
              ),
            )
          end

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
              @missing_count += 1
              :warning
            else
              @error_count += 1
              @error_samples << result if @error_samples.size < ERROR_SAMPLE_SIZE
              :error
            end
          end

          private

          # Drops the upload everywhere it's recorded — the Discourse record, the
          # migration-environment row, its optimized images, and every result that
          # points at it.
          # With the result rows gone, the following uploader task's incremental
          # skip no longer sees those source ids and recreates them.
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

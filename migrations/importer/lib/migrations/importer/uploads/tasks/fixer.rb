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
            @max_count ||=
              uploads_db.query_value("SELECT COUNT(*) FROM uploads WHERE upload IS NOT NULL")
          end

          def produce(emit_work:, _emit_result:)
            uploads_db.query(
              "SELECT id, upload FROM uploads WHERE upload IS NOT NULL ORDER BY rowid DESC",
            ) { |row| emit_work.call(row) }
          end

          def build_worker_resource
            OpenStruct.new(url: "")
          end

          def process(row, fake_upload)
            upload = JSON.parse(row[:upload], symbolize_names: true)
            fake_upload.url = upload[:url]
            path = add_multisite_prefix(discourse_store.get_path_for_upload(fake_upload))

            status = file_exists?(path) ? :ok : :missing
            { id: row[:id], upload_id: upload[:id], status: }
          rescue StandardError => e
            { id: row[:id], upload_id: upload&.dig(:id), status: :error, error: e.message }
          end

          def write(result)
            case result[:status]
            when :ok
              :ok
            when :missing
              uploads_db.execute("DELETE FROM uploads WHERE id = ?", result[:id])
              Upload.delete_by(id: result[:upload_id])
              reporter.notice(I18n.t("importer.uploads.fixer_missing", id: result[:id]))
              :warning
            else
              reporter.notice(
                I18n.t("importer.uploads.fixer_error", id: result[:id], error: result[:error]),
              )
              :error
            end
          end
        end
      end
    end
  end
end

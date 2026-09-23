# frozen_string_literal: true

module Migrations
  module Importer
    module Uploads
      module Tasks
        # Turns `upload_sources` rows into real Discourse uploads and records the
        # outcome in the files DB. The actual upload creation is delegated to the
        # shared {UploadCreationService}; this class only wires it up, feeds it the
        # rows on the pipeline's worker threads, and writes each {Result} on the
        # single writer thread.
        class Uploader < Base
          Status = Database::FilesDB::Enums::UploadResultStatus
          SkipReason = Database::FilesDB::Enums::UploadSkipReason
          UploadFileType = Database::FilesDB::Enums::UploadFileType

          UPLOAD_COLUMNS =
            Database::FilesDB::Upload.method(:create).parameters.map { |_type, name| name }.freeze

          def title
            "Uploading files"
          end

          def max_count
            @max_count
          end

          def before_run
            delete_reprocessable_uploads if settings[:delete_missing_uploads]
            load_tracking_sets
            handle_surplus_uploads if surplus_upload_ids.any?

            @seen_upload_ids = load_existing_ids(files_db, "SELECT id FROM uploads")
            @upload_service = build_upload_service

            @max_count = (@source_existing_ids - @output_existing_ids).size
            @source_existing_ids = nil

            reporter.notice(
              I18n.t(
                "importer.uploads.existing_summary",
                existing: @output_existing_ids.size,
                missing: @max_count,
              ),
            )
          end

          def produce(emit_work:, emit_result:)
            intermediate_db.query("SELECT * FROM upload_sources ORDER BY id") do |row|
              emit_work.call(row) if @output_existing_ids.exclude?(row[:id])
            end
          end

          # Every source file lands as an upload owned by the system user; the copy
          # step reassigns ownership to the mapped importer user afterwards.
          def process(row, _resource)
            result = @upload_service.create(row, user_id: Discourse::SYSTEM_USER_ID)
            return nil if result.nil?

            case result.status
            when Status::OK
              success_result(row, result.upload, result.markdown, result.download)
            when Status::SKIPPED
              missing_result(row)
            else
              error_result(
                row,
                skip_reason: result.skip_reason,
                skip_details: result.skip_details,
                download: result.download,
              )
            end
          end

          def write(result)
            record_download(result[:download]) if result[:download]

            if result[:status] == Status::ERROR
              reporter.notice(
                I18n.t(
                  "importer.uploads.upload_failed",
                  id: result[:id],
                  error: result[:skip_details],
                ),
              )
            end

            upload_id = write_upload(result[:upload])
            Database::FilesDB::UploadResult.create(
              id: result[:id],
              status: result[:status],
              skip_reason: result[:skip_reason],
              skip_details: result[:skip_details],
              markdown: result[:markdown],
              file_type: result[:file_type],
              upload_id:,
            )

            outcome_for(result[:status])
          rescue StandardError => e
            reporter.notice(
              I18n.t("importer.uploads.insert_failed", id: result[:id], error: e.message),
            )
            :error
          end

          private

          def build_upload_service
            UploadCreationService.new(
              locator:
                SourceFileLocator.new(
                  root_paths: settings[:root_paths],
                  path_replacements: settings[:path_replacements] || [],
                ),
              downloader:
                Downloader.new(
                  cache_path: settings[:download_cache_path],
                  downloads: reusable_downloads,
                ),
              discourse_store:,
              retry_policy: UploadCreationService.default_retry_policy,
            )
          end

          def load_tracking_sets
            @output_existing_ids = load_existing_ids(files_db, "SELECT id FROM upload_results")
            @source_existing_ids =
              load_existing_ids(intermediate_db, "SELECT id FROM upload_sources")
          end

          def surplus_upload_ids
            @surplus_upload_ids ||= @output_existing_ids - @source_existing_ids
          end

          def handle_surplus_uploads
            if settings[:delete_surplus_uploads]
              reporter.notice(
                I18n.t("importer.uploads.deleting_surplus", count: surplus_upload_ids.size),
              )

              surplus_upload_ids.each_slice(Database::Connection::TRANSACTION_BATCH_SIZE) do |ids|
                placeholders = (["?"] * ids.size).join(",")
                files_db.execute(<<~SQL, ids)
                  DELETE FROM upload_results
                  WHERE id IN (#{placeholders})
                SQL
              end

              delete_orphaned_files

              @output_existing_ids -= surplus_upload_ids
            else
              reporter.notice(
                I18n.t("importer.uploads.surplus_found", count: surplus_upload_ids.size),
              )
            end

            @surplus_upload_ids = nil
          end

          # Drops the results that never produced an upload so they get another try
          # on the next run.
          def delete_reprocessable_uploads
            files_db.execute("DELETE FROM upload_results WHERE upload_id IS NULL")
            delete_orphaned_files
          end

          # Removes `uploads` and `optimized_images` rows that no `upload_results`
          # row points at anymore, so deleting results cascades to the real files.
          def delete_orphaned_files
            files_db.execute(<<~SQL)
              DELETE FROM uploads
              WHERE NOT EXISTS (
                SELECT 1 FROM upload_results WHERE upload_results.upload_id = uploads.id
              )
            SQL
            files_db.execute(<<~SQL)
              DELETE FROM optimized_images
              WHERE NOT EXISTS (
                SELECT 1 FROM uploads WHERE uploads.id = optimized_images.upload_id
              )
            SQL
          end

          def success_result(row, upload, markdown, download_record)
            {
              id: row[:id],
              status: Status::OK,
              skip_reason: nil,
              skip_details: nil,
              markdown:,
              file_type: upload_file_type(upload.original_filename),
              upload: upload_attributes(upload),
              download: download_record,
            }
          end

          def missing_result(row)
            {
              id: row[:id],
              status: Status::SKIPPED,
              skip_reason: SkipReason::FILE_NOT_FOUND,
              skip_details: nil,
              markdown: nil,
              file_type: nil,
              upload: nil,
              download: nil,
            }
          end

          def error_result(row, skip_reason:, skip_details:, download:)
            {
              id: row[:id],
              status: Status::ERROR,
              skip_reason:,
              skip_details:,
              markdown: nil,
              file_type: nil,
              upload: nil,
              download:,
            }
          end

          def upload_attributes(upload)
            upload.attributes.symbolize_keys.slice(*UPLOAD_COLUMNS)
          end

          def upload_file_type(filename)
            if FileHelper.is_supported_image?(filename)
              UploadFileType::IMAGE
            elsif FileHelper.is_supported_audio?(filename)
              UploadFileType::AUDIO
            elsif FileHelper.is_supported_video?(filename)
              UploadFileType::VIDEO
            else
              UploadFileType::ATTACHMENT
            end
          end

          def outcome_for(status)
            case status
            when Status::OK
              :ok
            when Status::SKIPPED
              :skip
            else
              :error
            end
          end

          # Several source rows can dedup onto one Discourse upload (same sha1), so
          # the `uploads` row is written once and later results just reference its
          # id. Only the writer thread mutates the set, so `add?` is race-free.
          def write_upload(attributes)
            return nil if attributes.nil?

            upload_id = attributes[:id]
            Database::FilesDB::Upload.create(**attributes) if @seen_upload_ids.add?(upload_id)
            upload_id
          end

          def record_download(record)
            Database::FilesDB::Download.create(
              id: record[:id],
              original_filename: record[:original_filename],
            )
          end

          def reusable_downloads
            hash = {}
            files_db.query(<<~SQL) { |row| hash[row[:id]] = row[:original_filename] }
              SELECT downloads.id, downloads.original_filename
              FROM downloads
              LEFT JOIN upload_results ON upload_results.id = downloads.id
              WHERE upload_results.id IS NULL
            SQL
            hash
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module Migrations
  module Importer
    module Uploads
      module Tasks
        # Turns `upload_sources` rows into real Discourse uploads. The heavy
        # lifting (UploadCreator, downloads) runs on the pipeline's worker threads;
        # only {#write} touches the files DB, on the single writer thread.
        class Uploader < Base
          class DownloadFailedError < StandardError
          end

          class UploadSizeExceededError < DownloadFailedError
          end

          MAX_FILE_SIZE = 1.gigabyte
          # Post-store check retries: create succeeded but the file isn't in the
          # store yet. Try once more, then give up.
          POST_STORE_RETRIES = 1

          Status = Database::FilesDB::Enums::UploadResultStatus
          SkipReason = Database::FilesDB::Enums::UploadSkipReason

          # Columns the generated `FilesDB::Upload` model accepts. `upload.attributes`
          # also carries user_id/access_control_post_id/retain_hours/updated_at,
          # which the files DB schema drops, so we slice down to these.
          UPLOAD_COLUMNS = %i[
            id
            animated
            created_at
            dominant_color
            etag
            extension
            filesize
            height
            origin
            original_filename
            original_sha1
            secure
            security_last_changed_at
            security_last_changed_reason
            sha1
            thumbnail_height
            thumbnail_width
            url
            verification_status
            width
          ].freeze

          UploadMetadata = Struct.new(:original_filename, :origin_url, :description)

          def title
            "Uploading uploads"
          end

          def max_count
            @max_count
          end

          def before_run
            delete_reprocessable_uploads if settings[:delete_missing_uploads]
            load_tracking_sets
            handle_surplus_uploads if surplus_upload_ids.any?

            @seen_upload_ids = load_existing_ids(files_db, "SELECT id FROM uploads")
            @downloads = load_downloads

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

          def process(row, _resource)
            metadata = build_metadata(row)
            data_file = nil
            download_record = nil

            if row[:data].present?
              data_file = Tempfile.new("discourse-upload", binmode: true)
              data_file.write(row[:data])
              data_file.rewind
              path = data_file.path
            elsif row[:url].present?
              path, filename, download_record = download_file(url: row[:url], id: row[:id])
              return nil if path.nil? # nothing to download; not an error, drop the row

              metadata.original_filename = filename
              metadata.origin_url = row[:url]
            else
              path = find_file_in_paths(row)
              return missing_result(row) if path.nil?
            end

            create_upload_result(row, path, metadata, download_record)
          rescue UploadSizeExceededError => e
            error_result(
              row,
              skip_reason: SkipReason::UPLOAD_SIZE_EXCEEDED,
              skip_details: e.message,
              download: download_record,
            )
          rescue DownloadFailedError => e
            error_result(
              row,
              skip_reason: SkipReason::DOWNLOAD_ERROR,
              skip_details: e.message,
              download: download_record,
            )
          rescue StandardError => e
            skip_reason =
              retry_policy.transient?(e) ? SkipReason::TOO_MANY_RETRIES : SkipReason::ERROR
            error_result(row, skip_reason:, skip_details: e.message, download: download_record)
          ensure
            data_file&.close!
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

          def build_metadata(row)
            UploadMetadata.new(
              original_filename: row[:display_filename] || row[:filename],
              description: row[:description].presence,
            )
          end

          def find_file_in_paths(row)
            relative_path = row[:relative_path] || ""

            settings[:root_paths].each do |root_path|
              path = File.join(root_path, relative_path, row[:filename])
              return path if File.exist?(path)

              settings[:path_replacements].each do |from, to|
                path = File.join(root_path, relative_path.sub(from, to), row[:filename])
                return path if File.exist?(path)
              end
            end

            nil
          end

          # Creates the upload, retrying only what is worth retrying (see
          # {RetryPolicy}). A create that succeeds but whose file isn't in the
          # store yet gets one more try; validation errors and corrupt images are
          # recorded on the spot.
          def create_upload_result(row, path, metadata, download_record)
            attempt = 0

            loop do
              upload = build_upload(row, path, metadata)

              unless upload_valid?(upload)
                return(
                  error_result(
                    row,
                    skip_reason: SkipReason::ERROR,
                    skip_details: upload_error_message(upload),
                    download: download_record,
                  )
                )
              end

              if store_has_upload?(upload)
                return success_result(row, upload, metadata, download_record)
              end

              # Created but not in the store — drop it and try once more.
              upload.destroy
              attempt += 1
              if attempt > POST_STORE_RETRIES
                return(
                  error_result(
                    row,
                    skip_reason: SkipReason::TOO_MANY_RETRIES,
                    skip_details: "file missing from store after upload",
                    download: download_record,
                  )
                )
              end

              sleep(retry_policy.backoff(attempt - 1))
            end
          end

          def build_upload(row, path, metadata)
            recover = {
              # Another worker inserted the same sha1 first. Use its row instead of
              # re-running the whole upload.
              ActiveRecord::RecordNotUnique => ->(_error) do
                Upload.find_by(sha1: Upload.generate_digest(path))
              end,
            }

            retry_policy.run(recover:) do
              copy_to_tempfile(path) do |file|
                UploadCreator.new(
                  file,
                  metadata.original_filename,
                  type: row[:type],
                  origin: metadata.origin_url,
                ).create_for(Discourse::SYSTEM_USER_ID)
              end
            end
          end

          def upload_valid?(upload)
            upload.present? && upload.persisted? && upload.errors.blank?
          end

          def upload_error_message(upload)
            upload&.errors&.full_messages&.join(", ").presence || "unknown error"
          end

          def store_has_upload?(upload)
            file_exists?(add_multisite_prefix(discourse_store.get_path_for_upload(upload)))
          end

          def success_result(row, upload, metadata, download_record)
            {
              id: row[:id],
              status: Status::OK,
              skip_reason: nil,
              skip_details: nil,
              markdown: UploadMarkdown.new(upload).to_markdown(display_name: metadata.description),
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
              upload: nil,
              download:,
            }
          end

          def upload_attributes(upload)
            upload.attributes.symbolize_keys.slice(*UPLOAD_COLUMNS)
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
            # Keep the in-memory cache current so a later row that hits the same
            # download id finds it. Writer-thread only, matching the insert above.
            @downloads[record[:id]] = record[:original_filename]
          end

          def retry_policy
            @retry_policy ||= RetryPolicy.new(transient_errors: transient_error_classes)
          end

          def transient_error_classes
            classes = [
              Net::OpenTimeout,
              Net::ReadTimeout,
              Errno::ECONNRESET,
              ActiveRecord::Deadlocked,
              ActiveRecord::RecordNotUnique,
            ]
            classes << Aws::S3::Errors::ServiceError if defined?(Aws::S3::Errors::ServiceError)
            classes
          end

          # --- Download cache. The whole `downloads` table is read into a Hash in
          # `before_run`, so the workers never touch the DB connection to look up a
          # cached filename. A fresh download's record travels back on its result
          # and is inserted (and added to the Hash) by {#write} on the writer
          # thread. A download id is processed at most once per run, so no worker
          # ever reads a key while the writer is adding it. ---

          def load_downloads
            hash = {}
            files_db.query("SELECT id, original_filename FROM downloads") do |row|
              hash[row[:id]] = row[:original_filename]
            end
            hash
          end

          def download_file(url:, id:)
            path = download_cache_path(id)

            if File.exist?(path) && (filename = get_original_filename(id))
              return path, filename, nil
            end

            file = nil
            filename = nil

            begin
              fd = FinalDestination.new(url)

              fd.get do |response, chunk, uri|
                if file.nil?
                  check_response!(response, uri)
                  filename = extract_filename_from_response(response, uri)
                  file = File.open(path, "wb")
                end

                file.write(chunk)

                if file.size > MAX_FILE_SIZE
                  File.unlink(path)
                  raise UploadSizeExceededError,
                        "Upload size #{file.size} bytes exceeds the limit of #{MAX_FILE_SIZE} bytes"
                end
              end

              return nil, nil, nil if file.nil?

              [path, filename, { id:, original_filename: filename }]
            rescue UploadSizeExceededError
              raise
            rescue StandardError => e
              raise DownloadFailedError, "Failed to download upload from #{url}: #{e.message}"
            ensure
              file&.close
            end
          end

          def download_cache_path(id)
            id = id.gsub("/", "_").gsub("=", "-")
            File.join(settings[:download_cache_path], id)
          end

          def get_original_filename(id)
            @downloads[id]
          end

          def check_response!(response, uri)
            return if uri.present?

            if response.code.to_i >= 400
              response.value
            else
              throw :done
            end
          end

          def extract_filename_from_response(response, uri)
            filename =
              if (header = response.header["Content-Disposition"].presence)
                disposition_filename =
                  header[/filename\*=UTF-8''(\S+)\b/i, 1] ||
                    header[/filename=(?:"(.+)"|[^\s;]+)/i, 1]
                URI.decode_www_form_component(disposition_filename) if disposition_filename.present?
              end

            filename = File.basename(uri.path).presence || "file" if filename.blank?

            if File.extname(filename).blank? && response.content_type.present?
              ext = MiniMime.lookup_by_content_type(response.content_type)&.extension
              filename = "#{filename}.#{ext}" if ext.present?
            end

            filename
          end

          def copy_to_tempfile(source_path)
            extension = File.extname(source_path)

            Tempfile.open(["discourse-upload", extension]) do |tmpfile|
              File.open(source_path, "rb") do |source_stream|
                IO.copy_stream(source_stream, tmpfile)
              end
              tmpfile.rewind
              yield(tmpfile)
            end
          end
        end
      end
    end
  end
end

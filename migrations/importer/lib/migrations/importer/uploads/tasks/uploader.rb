# frozen_string_literal: true

module Migrations
  module Importer
    module Uploads
      module Tasks
        # Turns `upload_sources` rows into real Discourse uploads. The heavy
        # lifting (UploadCreator, downloads) runs on the pipeline's worker threads;
        # only {#write} touches the uploads DB, on the single writer thread.
        class Uploader < Base
          MAX_FILE_SIZE = 1.gigabyte
          # Post-store check retries: create succeeded but the file isn't in the
          # store yet. Try once more, then give up.
          POST_STORE_RETRIES = 1

          SKIP_FILE_NOT_FOUND = "file not found"
          SKIP_TOO_MANY_RETRIES = "too many retries"
          SKIP_ERROR = "error"

          UploadMetadata = Struct.new(:original_filename, :origin_url, :description)

          def title
            "Uploading uploads"
          end

          def max_count
            @max_count
          end

          def before_run
            delete_missing_uploads if settings[:delete_missing_uploads]
            load_tracking_sets
            handle_surplus_uploads if surplus_upload_ids.any?

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
              return nil if path.nil? # download failed; retried on the next run

              metadata.original_filename = filename
              metadata.origin_url = row[:url]
            else
              path = find_file_in_paths(row)
              return missing_result(row) if path.nil?
            end

            create_upload_result(row, path, metadata, download_record)
          rescue StandardError => e
            skip_reason = retry_policy.transient?(e) ? SKIP_TOO_MANY_RETRIES : SKIP_ERROR
            error_result(row, skip_reason:, error: e.message, download: download_record)
          ensure
            data_file&.close!
          end

          def write(result)
            record_download(result[:download]) if result[:download]

            outcome = classify(result)
            if outcome == :error
              reporter.notice(
                I18n.t("importer.uploads.upload_failed", id: result[:id], error: result[:error]),
              )
            end

            uploads_db.insert(<<~SQL, insert_params(result))
              INSERT INTO uploads (id, upload, markdown, skip_reason)
              VALUES (:id, :upload, :markdown, :skip_reason)
            SQL

            outcome
          rescue StandardError => e
            reporter.notice(
              I18n.t("importer.uploads.insert_failed", id: result[:id], error: e.message),
            )
            :error
          end

          private

          def load_tracking_sets
            @output_existing_ids = load_existing_ids(uploads_db, "SELECT id FROM uploads")
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
                uploads_db.execute(<<~SQL, ids)
                  DELETE FROM uploads
                  WHERE id IN (#{placeholders})
                SQL
              end

              @output_existing_ids -= surplus_upload_ids
            else
              reporter.notice(
                I18n.t("importer.uploads.surplus_found", count: surplus_upload_ids.size),
              )
            end

            @surplus_upload_ids = nil
          end

          def delete_missing_uploads
            uploads_db.execute("DELETE FROM uploads WHERE upload IS NULL")
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
                    skip_reason: SKIP_ERROR,
                    error: upload_error_message(upload),
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
                    skip_reason: SKIP_TOO_MANY_RETRIES,
                    error: "file missing from store after upload",
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
              upload: upload.attributes.to_json,
              markdown: UploadMarkdown.new(upload).to_markdown(display_name: metadata.description),
              skip_reason: nil,
              download: download_record,
            }
          end

          def missing_result(row)
            {
              id: row[:id],
              upload: nil,
              markdown: nil,
              skip_reason: SKIP_FILE_NOT_FOUND,
              skipped: true,
            }
          end

          def error_result(row, skip_reason:, error:, download:)
            { id: row[:id], upload: nil, markdown: nil, skip_reason:, error:, download: }
          end

          def classify(result)
            if result[:skipped]
              :skip
            elsif result[:error] || result[:upload].nil?
              :error
            else
              :ok
            end
          end

          def insert_params(result)
            {
              id: result[:id],
              upload: result[:upload],
              markdown: result[:markdown],
              skip_reason: result[:skip_reason],
            }
          end

          def record_download(record)
            uploads_db.insert(
              "INSERT INTO downloads (id, original_filename) VALUES (?, ?)",
              [record[:id], record[:original_filename]],
            )
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

          # --- Download cache. The file is written here on the worker; its DB
          # record travels back on a result and is inserted by {#write}, so the
          # writer thread stays the only one touching the connection. ---

          def download_file(url:, id:)
            path = download_cache_path(id)

            if File.exist?(path) && (filename = get_original_filename(id))
              return path, filename, nil
            end

            fd = FinalDestination.new(url)
            file = nil
            filename = nil

            fd.get do |response, chunk, uri|
              if file.nil?
                check_response!(response, uri)
                filename = extract_filename_from_response(response, uri)
                file = File.open(path, "wb")
              end

              file.write(chunk)

              if file.size > MAX_FILE_SIZE
                file.close
                file.unlink
                file = nil
                throw :done
              end
            end

            return nil if file.nil?

            file.close
            [path, filename, { id:, original_filename: filename }]
          end

          def download_cache_path(id)
            id = id.gsub("/", "_").gsub("=", "-")
            File.join(settings[:download_cache_path], id)
          end

          def get_original_filename(id)
            uploads_db.query_value("SELECT original_filename FROM downloads WHERE id = ?", id)
          end

          def check_response!(response, uri)
            return if uri.present?

            code = response.code.to_i
            raise "#{code} Error" if code >= 400

            throw :done
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

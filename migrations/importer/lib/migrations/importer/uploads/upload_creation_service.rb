# frozen_string_literal: true

require "digest/xxhash"
require "tempfile"

module Migrations
  module Importer
    module Uploads
      # Creates a single upload, for both upload paths. Given one `upload_sources` row,
      # it finds or downloads the file, passes it to core's `UploadCreator`,
      # checks that the file is in the store, retries the few failures that are
      # worth retrying, and returns a frozen {Result}.
      #
      # It does no queueing and no DB writes: `disco upload` and the inline import
      # path each persist the {Result} their own way, on their own writer thread.
      # That is what lets the two share this code — the only thing that differs is
      # who owns the upload (`user_id`) and where the result is recorded.
      class UploadCreationService
        include StoreProbe

        Status = Database::FilesDB::Enums::UploadResultStatus
        SkipReason = Database::FilesDB::Enums::UploadSkipReason

        # Created but not in the store yet: try once more, then give up.
        POST_STORE_RETRIES = 1

        # Uploads with the same content must not be created at the same time:
        # `UploadCreator` can destroy an upload with the same sha1 that another
        # thread has not finished yet.
        #
        # The workers are threads of one process, so an in-process lock is
        # enough. The lock is picked by a fast non-cryptographic hash of the
        # content. When two different files get the same lock, they only wait
        # for each other; nothing breaks.
        CREATE_LOCK_COUNT = 256
        CREATE_LOCKS = Array.new(CREATE_LOCK_COUNT) { Mutex.new }.freeze

        # The outcome of one row. `upload` is the core `Upload` (nil unless
        # created), `markdown` is its rendered reference, and `download` is a fresh
        # download's `{ id:, original_filename: }` record (nil otherwise) that the
        # caller persists so a resumed run can skip re-fetching the filename. It is
        # set on error results too: the file is on disk, so a retry can reuse it.
        Result =
          Struct.new(
            :source_id,
            :status,
            :upload,
            :markdown,
            :skip_reason,
            :skip_details,
            :download,
            keyword_init: true,
          )

        Metadata = Struct.new(:original_filename, :origin_url, :description)

        attr_reader :discourse_store

        # The upload path's transient failures: network hiccups, deadlocks, and the
        # duplicate-sha1 race. Everything else is treated as permanent (see
        # {RetryPolicy}).
        def self.default_retry_policy
          classes = [
            Net::OpenTimeout,
            Net::ReadTimeout,
            Errno::ECONNRESET,
            ActiveRecord::Deadlocked,
            ActiveRecord::RecordNotUnique,
          ]
          classes << Aws::S3::Errors::ServiceError if defined?(Aws::S3::Errors::ServiceError)
          RetryPolicy.new(transient_errors: classes)
        end

        def self.build(root_paths:, path_replacements:, cache_path:, downloads:, discourse_store:)
          new(
            locator: SourceFileLocator.new(root_paths:, path_replacements: path_replacements || []),
            downloader: Downloader.new(cache_path:, downloads:),
            discourse_store:,
            retry_policy: default_retry_policy,
          )
        end

        def initialize(locator:, downloader:, discourse_store:, retry_policy:)
          @locator = locator
          @downloader = downloader
          @discourse_store = discourse_store
          @retry_policy = retry_policy
        end

        # Turns one `upload_sources` row into an upload owned by `user_id`. Returns
        # a {Result}, or nil when the row pointed at a URL with nothing to download
        # (not an error — the caller just drops it).
        def create(row, user_id:)
          metadata = build_metadata(row)
          data_file = nil
          download_record = nil

          if row[:data].present?
            data_file = @locator.tempfile_from_data(row[:data])
            path = data_file.path
          elsif row[:url].present?
            path, filename, download_record = @downloader.download(url: row[:url], id: row[:id])
            return nil if path.nil?

            metadata.original_filename = filename
            metadata.origin_url = row[:url]
          else
            path = @locator.find_file_in_paths(row)
            return missing_result(row) if path.nil?
          end

          create_with_retries(row, path, metadata, user_id, download_record)
        rescue Downloader::UploadSizeExceededError => e
          error_result(
            row,
            skip_reason: SkipReason::UPLOAD_SIZE_EXCEEDED,
            skip_details: e.message,
            download: download_record,
          )
        rescue Downloader::DownloadFailedError => e
          error_result(
            row,
            skip_reason: SkipReason::DOWNLOAD_ERROR,
            skip_details: e.message,
            download: download_record,
          )
        rescue StandardError => e
          skip_reason =
            @retry_policy.transient?(e) ? SkipReason::TOO_MANY_RETRIES : SkipReason::ERROR
          error_result(row, skip_reason:, skip_details: e.message, download: download_record)
        ensure
          data_file&.close!
        end

        private

        def build_metadata(row)
          Metadata.new(original_filename: row[:filename], description: row[:description].presence)
        end

        # Creates the upload, retrying only what is worth retrying (see
        # {RetryPolicy}). A create that succeeds but whose file isn't in the store
        # yet gets one more try; validation errors and corrupt images are recorded
        # on the spot.
        def create_with_retries(row, path, metadata, user_id, download_record)
          attempt = 0

          loop do
            upload = build_upload(row, path, metadata, user_id)

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

            sleep(@retry_policy.backoff(attempt - 1))
          end
        end

        def build_upload(row, path, metadata, user_id)
          recover = {
            # Another worker inserted the same sha1 first. Use its row instead of
            # re-running the whole upload.
            ActiveRecord::RecordNotUnique => ->(_error) do
              Upload.find_by(sha1: Upload.generate_digest(path))
            end,
          }

          lock = create_lock_for(path)

          @retry_policy.run(recover:) do
            copy_to_tempfile(path) do |file|
              creator =
                UploadCreator.new(
                  file,
                  metadata.original_filename,
                  type: row[:type],
                  origin: metadata.origin_url,
                )
              lock.synchronize { creator.create_for(user_id) }
            end
          end
        end

        def create_lock_for(path)
          CREATE_LOCKS[Digest::XXH3_64bits.file(path).idigest % CREATE_LOCK_COUNT]
        end

        def upload_valid?(upload)
          upload.present? && upload.persisted? && upload.errors.blank?
        end

        def upload_error_message(upload)
          upload&.errors&.full_messages&.join(", ").presence || "unknown error"
        end

        def store_has_upload?(upload)
          file_exists?(add_multisite_prefix(@discourse_store.get_path_for_upload(upload)))
        end

        def success_result(row, upload, metadata, download_record)
          Result.new(
            source_id: row[:id],
            status: Status::OK,
            upload:,
            markdown: UploadMarkdown.new(upload).to_markdown(display_name: metadata.description),
            skip_reason: nil,
            skip_details: nil,
            download: download_record,
          ).freeze
        end

        def missing_result(row)
          Result.new(
            source_id: row[:id],
            status: Status::SKIPPED,
            upload: nil,
            markdown: nil,
            skip_reason: SkipReason::FILE_NOT_FOUND,
            skip_details: nil,
            download: nil,
          ).freeze
        end

        def error_result(row, skip_reason:, skip_details:, download:)
          Result.new(
            source_id: row[:id],
            status: Status::ERROR,
            upload: nil,
            markdown: nil,
            skip_reason:,
            skip_details:,
            download:,
          ).freeze
        end

        def copy_to_tempfile(source_path)
          extension = File.extname(source_path)

          Tempfile.open(["discourse-upload", extension]) do |tmpfile|
            File.open(source_path, "rb") { |source_stream| IO.copy_stream(source_stream, tmpfile) }
            tmpfile.rewind
            yield(tmpfile)
          end
        end
      end
    end
  end
end

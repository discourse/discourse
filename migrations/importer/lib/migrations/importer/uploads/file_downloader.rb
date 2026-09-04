# frozen_string_literal: true

require "tempfile"

module Migrations
  module Importer
    module Uploads
      # Downloads a URL-backed `upload_sources` row to a file on disk. The error
      # taxonomy (see #33546) is deliberate: a size overrun and a plain download
      # failure are told apart so the caller can record different skip reasons.
      #
      # The filename store is injected so the two callers can persist it
      # differently: `disco upload` keeps it in the files DB (so a resumed run
      # recovers the original filename for a file already on disk), while the
      # inline import path keeps it in a plain in-memory Hash. Either way the
      # downloader only *reads* the store; the caller persists a fresh download's
      # record (returned alongside the file) on its writer thread, matching the
      # cache dir which works the same in both.
      class FileDownloader
        class DownloadFailedError < StandardError
        end

        class UploadSizeExceededError < DownloadFailedError
        end

        MAX_FILE_SIZE = 1.gigabyte

        Result = Struct.new(:path, :filename, :record, keyword_init: true)

        # @param cache_path [String] directory fresh downloads are written into
        # @param filename_store [#[]] maps a download id to its cached filename
        # @param max_file_size [Integer] hard byte ceiling per download
        def initialize(cache_path:, filename_store:, max_file_size: MAX_FILE_SIZE)
          @cache_path = cache_path
          @filename_store = filename_store
          @max_file_size = max_file_size
        end

        # Downloads `url` into the cache under `id`. Returns a {Result}; `record`
        # is nil on a cache hit (nothing new to persist) and `{ id:, filename: }`
        # on a fresh download. Returns nil when there was nothing to download.
        #
        # @raise [UploadSizeExceededError] the response exceeded `max_file_size`
        # @raise [DownloadFailedError] the download otherwise failed
        def download(url:, id:)
          path = cache_path_for(id)

          if File.exist?(path) && (filename = @filename_store[id])
            return Result.new(path:, filename:, record: nil)
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

              if file.size > @max_file_size
                File.unlink(path)
                raise UploadSizeExceededError,
                      "Upload size #{file.size} bytes exceeds the limit of #{@max_file_size} bytes"
              end
            end

            return nil if file.nil?

            Result.new(path:, filename:, record: { id:, original_filename: filename })
          rescue UploadSizeExceededError
            raise
          rescue StandardError => e
            raise DownloadFailedError, "Failed to download upload from #{url}: #{e.message}"
          ensure
            file&.close
          end
        end

        private

        def cache_path_for(id)
          id = id.gsub("/", "_").gsub("=", "-")
          File.join(@cache_path, id)
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
                header[/filename\*=UTF-8''(\S+)\b/i, 1] || header[/filename=(?:"(.+)"|[^\s;]+)/i, 1]
              URI.decode_www_form_component(disposition_filename) if disposition_filename.present?
            end

          filename = File.basename(uri.path).presence || "file" if filename.blank?

          if File.extname(filename).blank? && response.content_type.present?
            ext = MiniMime.lookup_by_content_type(response.content_type)&.extension
            filename = "#{filename}.#{ext}" if ext.present?
          end

          filename
        end
      end
    end
  end
end

# frozen_string_literal: true

module Migrations
  module Importer
    module Uploads
      # Downloads remote upload sources and reuses files recorded in the download
      # cache. Workers share an immutable snapshot of filenames for downloads that
      # have no result yet; completed source IDs will not be processed again.
      class Downloader
        class DownloadFailedError < StandardError
        end

        class UploadSizeExceededError < DownloadFailedError
        end

        MAX_FILE_SIZE = 1.gigabyte

        def initialize(cache_path:, downloads:)
          @cache_path = cache_path
          @downloads = downloads.freeze
        end

        def download(url:, id:)
          path = cache_path(id)

          if File.exist?(path) && (filename = @downloads[id])
            return path, filename, nil
          end

          fetch(url, id, path)
        end

        private

        def fetch(url, id, path)
          file = nil
          filename = nil

          begin
            FinalDestination
              .new(url)
              .get do |response, chunk, uri|
                if file.nil?
                  check_response!(response, uri)
                  filename = extract_filename(response, uri)
                  file = File.open(path, "wb")
                end

                file.write(chunk)

                if file.size > MAX_FILE_SIZE
                  File.unlink(path)
                  raise UploadSizeExceededError,
                        "Upload size #{file.size} bytes exceeds the limit of #{MAX_FILE_SIZE} bytes"
                end
              end

            return nil if file.nil?

            [path, filename, { id:, original_filename: filename }]
          rescue UploadSizeExceededError
            raise
          rescue StandardError => e
            raise DownloadFailedError, "Failed to download upload from #{url}: #{e.message}"
          ensure
            file&.close
          end
        end

        def cache_path(id)
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

        def extract_filename(response, uri)
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

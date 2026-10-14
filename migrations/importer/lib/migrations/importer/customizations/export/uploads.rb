# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      module Export
        # Copies referenced upload files into the bundle and hands out the
        # portable reference that replaces the upload id.
        class Uploads
          MAX_DOWNLOAD_SIZE = 200 * 1024 * 1024

          def initialize(writer, base_url: nil)
            @writer = writer
            @base_url = base_url.presence&.chomp("/")
            @refs = {}
          end

          # @return [Hash] `{"upload" => "uploads/<file>", "original_filename" => ...}`
          def ref(upload_or_id)
            upload =
              upload_or_id.is_a?(::Upload) ? upload_or_id : ::Upload.find_by(id: upload_or_id)
            raise Error, "upload #{upload_or_id} does not exist" if upload.nil?

            @refs[upload.id] ||= with_file(upload) do |path|
              {
                "upload" => @writer.add_upload(path, upload.original_filename),
                "original_filename" => upload.original_filename,
              }
            end
          end

          private

          def with_file(upload)
            path = local_path(upload)
            return yield(path) if path

            file = store_download(upload) || http_download(upload)
            if file.nil?
              hint = @base_url ? "" : "; pass --upload-base-url to download it from the site"
              raise Error,
                    "file of upload #{upload.id} (#{upload.original_filename}) not found#{hint}"
            end

            begin
              yield file.path
            ensure
              file.close! if file.respond_to?(:close!)
            end
          end

          def local_path(upload)
            path = ::Discourse.store.path_for(upload)
            path if path && File.file?(path)
          rescue StandardError
            nil
          end

          def store_download(upload)
            return unless ::Discourse.store.external?
            ::Discourse.store.download(upload)
          end

          def http_download(upload)
            return if @base_url.nil? || upload.url.blank?

            url =
              if upload.url.start_with?("//")
                "#{URI(@base_url).scheme}:#{upload.url}"
              elsif upload.url.match?(%r{\Ahttps?://})
                upload.url
              else
                "#{@base_url}#{upload.url}"
              end
            ::FileHelper.download(
              url,
              max_file_size: MAX_DOWNLOAD_SIZE,
              tmp_file_name: "customizations-upload",
              follow_redirect: true,
            )
          rescue StandardError
            nil
          end
        end
      end
    end
  end
end

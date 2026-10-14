# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      module Apply
        # Creates uploads from bundle files on first use. Files already on the
        # site (same SHA1) are reused, which keeps repeated applies idempotent.
        class Uploads
          def initialize(bundle, dry_run:)
            @bundle = bundle
            @dry_run = dry_run
            @ids = {}
          end

          # @return [Integer, nil]
          def id_for(ref)
            return if ref.nil? || ref == ""
            unless ref.is_a?(Hash) && ref["upload"].is_a?(String)
              raise Error, "invalid upload reference: #{ref.inspect}"
            end

            @ids[ref["upload"]] ||= begin
              path = @bundle.file_path(ref["upload"], prefix: Bundle::UPLOADS_DIR)
              filename =
                File.basename(ref["original_filename"].to_s).presence || File.basename(path)
              existing_id(path) || create(path, filename)
            end
          end

          private

          def existing_id(path)
            sha1 = ::Upload.generate_digest(path)
            ::Upload.where(sha1:).or(::Upload.where(original_sha1: sha1)).pick(:id)
          end

          def create(path, filename)
            raise PendingDependency, "upload #{filename} would be created" if @dry_run

            upload =
              File.open(path) do |file|
                ::UploadCreator.new(
                  file,
                  filename,
                  for_site_setting: true,
                  skip_validations: true,
                ).create_for(::Discourse.system_user.id)
              end

            if upload.errors.any? || !upload.persisted?
              raise Error,
                    "could not create upload #{filename}: #{upload.errors.full_messages.join(", ")}"
            end
            upload.id
          end
        end
      end
    end
  end
end

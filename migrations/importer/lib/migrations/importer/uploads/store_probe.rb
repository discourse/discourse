# frozen_string_literal: true

module Migrations
  module Importer
    module Uploads
      # Shared "is this file in the store?" helpers. The upload tasks and the
      # inline upload service both need to check whether a file landed in the
      # Discourse store (local dir or S3), so the logic lives here instead of being
      # copied. The including object only has to expose `discourse_store`.
      module StoreProbe
        def add_multisite_prefix(path)
          return path if !Rails.configuration.multisite

          File.join("uploads", RailsMultisite::ConnectionManagement.current_db, path)
        end

        def file_exists?(path)
          if discourse_store.external?
            discourse_store.object_from_path(path).exists?
          else
            File.exist?(File.join(discourse_store.public_dir, path))
          end
        end
      end
    end
  end
end

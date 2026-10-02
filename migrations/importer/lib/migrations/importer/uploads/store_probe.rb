# frozen_string_literal: true

module Migrations
  module Importer
    module Uploads
      # Helpers about the Discourse store (local dir or S3) for the upload tasks,
      # the inline upload task and the upload service. The including object only
      # has to expose `discourse_store`.
      module StoreProbe
        # The pipeline allows more workers for an external store (S3), because
        # those uploads mostly wait on the network instead of using the CPU.
        def store_external?
          discourse_store.external?
        end

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

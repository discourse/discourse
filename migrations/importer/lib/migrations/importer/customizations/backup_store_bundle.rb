# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      # Fetches a bundle from the site's backup store (S3 or local), so it can be
      # put next to the backups instead of being copied onto the server.
      module BackupStoreBundle
        def self.open(filename, store: ::BackupRestore::BackupStore.create)
          if filename.blank? || File.basename(filename) != filename
            raise Error, "#{filename.inspect} must be a file name in the backup store, not a path"
          end
          if store.file(filename).nil?
            raise Error,
                  "#{filename} not found in the #{::SiteSetting.backup_location} backup store"
          end

          Dir.mktmpdir("customizations") do |dir|
            path = File.join(dir, filename)
            begin
              store.download_file(filename, path)
            rescue StandardError => e
              raise Error, "could not download #{filename} from the backup store: #{e.message}"
            end
            yield path
          end
        end
      end
    end
  end
end

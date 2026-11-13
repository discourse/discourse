# frozen_string_literal: true

require "extralite"

module Migrations
  module Importer
    module Customizations
      # Read-only view of the importer's MappingsDB `ids` table.
      class MappingsDB
        def initialize(path)
          raise Error, "MappingsDB not found: #{path}" unless File.exist?(path)

          @db = Extralite::Database.new(path, read_only: true, stmt_cache: false)
        end

        # A MappingsDB the importer hasn't opened since `ids_discourse_id` was
        # added scans the whole table per call; read-only, it can't be added here.
        def original_id(type, discourse_id)
          @db.query_single_splat(
            "SELECT original_id FROM ids WHERE type = ? AND discourse_id = ? LIMIT 1",
            type,
            discourse_id,
          )
        end

        def discourse_id(type, original_id)
          @db.query_single_splat(
            "SELECT discourse_id FROM ids WHERE original_id = ? AND type = ?",
            original_id,
            type,
          )
        end

        def close
          @db.close
        end
      end
    end
  end
end

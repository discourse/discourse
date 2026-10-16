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
          @by_type = {}
        end

        def original_id(type, discourse_id)
          mappings(type)[:to_original][discourse_id.to_s]
        end

        def discourse_id(type, original_id)
          mappings(type)[:to_discourse][original_id.to_s]
        end

        def close
          @db.close
        end

        private

        # The mapped types this tool needs (categories, groups) are small, so
        # load each one once instead of querying per lookup.
        def mappings(type)
          @by_type[type] ||= begin
            to_original = {}
            to_discourse = {}
            @db
              .query_splat("SELECT original_id, discourse_id FROM ids WHERE type = ?", type)
              .each do |original_id, discourse_id|
                to_original[discourse_id.to_s] = original_id
                to_discourse[original_id.to_s] = discourse_id
              end
            { to_original:, to_discourse: }
          end
        end
      end
    end
  end
end

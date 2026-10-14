# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      class Matcher
        module Strategies
          # Ids recorded by the importer in its MappingsDB.
          class Mappings
            TYPES = { category: MappingType::CATEGORIES, group: MappingType::GROUPS }.freeze

            def initialize(mappings_db)
              @mappings_db = mappings_db
            end

            def name
              "mappings_db"
            end

            def keys_for(kind, record)
              { "original_id" => @mappings_db.original_id(TYPES.fetch(kind), record.id) }
            end

            def find_id(kind, keys)
              return if keys["original_id"].nil?

              id = @mappings_db.discourse_id(TYPES.fetch(kind), keys["original_id"])
              id&.to_i
            end

            def close
              @mappings_db.close
            end
          end
        end
      end
    end
  end
end

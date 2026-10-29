# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      class Matcher
        module Strategies
          # Ids recorded by the importer in its MappingsDB.
          class Mappings
            TYPES = {
              category: MappingType::CATEGORIES,
              group: MappingType::GROUPS,
              topic: MappingType::TOPICS,
              user: MappingType::USERS,
              tag: MappingType::TAGS,
            }.freeze

            def initialize(mappings_db)
              @mappings_db = mappings_db
            end

            def name
              "mappings_db"
            end

            # Posts have no mapping type.
            def keys_for(kind, record)
              type = TYPES[kind]
              return {} if type.nil?

              { "original_id" => @mappings_db.original_id(type, record.id) }
            end

            def find_id(kind, keys)
              type = TYPES[kind]
              return if type.nil? || keys["original_id"].nil?

              @mappings_db.discourse_id(type, keys["original_id"])&.to_i
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

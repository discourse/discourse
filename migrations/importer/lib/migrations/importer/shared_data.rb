# frozen_string_literal: true

module Migrations
  module Importer
    class SharedData
      LOADERS = {
        existing_usernames_lower: {
          type: :set,
          sql: <<~SQL,
            SELECT username_lower
            FROM users
          SQL
        },
        existing_group_names_lower: {
          type: :set,
          sql: <<~SQL,
            SELECT LOWER(name)
            FROM groups
          SQL
        },
      }.freeze

      def initialize(discourse_db)
        @discourse_db = discourse_db
        @cache = {}
      end

      def load_set(sql)
        result = @discourse_db.query_result(sql)
        depth = result.column_count - 1

        set = SetStore.create(depth)
        set.bulk_add(result.rows)

        set
      end

      def load_mapping(sql)
        result = {}
        @discourse_db
          .query_array(sql)
          .each { |key, *values| result[key] = values.size > 1 ? values : values.first }
        result
      end

      def [](type)
        @cache[type] ||= begin
          loader_config = LOADERS[type]
          raise "Unknown type: #{type}" unless loader_config

          sql = loader_config[:sql]
          case loader_config[:type]
          when :set
            load_set(sql)
          when :mapping
            load_mapping(sql)
          else
            raise "Unknown loader type: #{loader_config[:type]}"
          end
        end
      end
    end
  end
end

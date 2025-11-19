# frozen_string_literal: true

module Migrations::Importer
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

      set = Migrations::SetStore.create(depth)
      set.bulk_add(result.rows)

      set
    end

    def load_mapping(sql)
      rows = @discourse_db.query_array(sql)

      # While rows is an enumerator, it's not fully compliant, it does not
      # rewind on #first, #peek, #any?, etc.
      # So we need to hold on to first_row for use later
      first_row = rows.first

      return {} if first_row.nil?

      has_multiple_values = first_row.size > 2
      result =
        if has_multiple_values
          rows.to_h { |key, *values| [key, values] }
        else
          rows.to_h
        end

      result[first_row[0]] = has_multiple_values ? first_row[1..] : first_row[1]
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

# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableRowsRepository
    SORT_DIRECTIONS = { "asc" => "ASC", "desc" => "DESC" }.freeze
    MAX_LIMIT = 100

    class << self
      def count_for(data_table)
        new(data_table).count
      end
    end

    def initialize(data_table)
      @data_table = data_table
      @column_map = DataTableRow.column_map(data_table)
      @table = DataTableStorage.quoted_table(data_table.id)
    end

    def count(filter: nil)
      where_clause, binds = build_where_clause(filter, optional: true)
      result = DB.query_single("SELECT COUNT(*) FROM #{@table}#{where_clause}", binds)
      result.first.to_i
    end

    def get_many_and_count(filter: nil, limit: nil, offset: nil, sort_by: nil, sort_direction: nil)
      normalized_filter = normalize_filter(filter, optional: true)
      where_clause, binds = build_where_clause(normalized_filter, optional: true)
      order_clause = build_order_clause(sort_by, sort_direction)
      limit_clause = build_limit_clause(limit, binds)
      offset_clause = build_offset_clause(offset, binds)

      results = DB.query_hash(<<~SQL, binds)
            SELECT *, COUNT(*) OVER() AS _total_count FROM #{@table}
            #{where_clause}
            #{order_clause}
            #{limit_clause}
            #{offset_clause}
          SQL

      total_count = results.first&.dig("_total_count").to_i
      rows = results.map { |row| serialize_row(row.except("_total_count")) }

      { rows: rows, count: total_count }
    end

    def find(row_id)
      DB
        .query_hash("SELECT * FROM #{@table} WHERE id = :row_id", row_id: row_id)
        .first
        &.then { |row| serialize_row(row) }
    end

    def insert(data)
      row = DataTableRow.normalize_row_data(@data_table, data, fill_missing: true)

      result =
        if row.empty?
          DB.query_hash("INSERT INTO #{@table} DEFAULT VALUES RETURNING *").first
        else
          binds = {}
          quoted_columns, placeholders =
            row
              .keys
              .each_with_index
              .each_with_object([[], []]) do |(column_name, index), (cols, phs)|
                bind_name = :"value_#{index}"
                cols << DataTableStorage.quoted_column(column_name)
                phs << ":#{bind_name}"
                binds[bind_name] = row[column_name]
              end

          DB.query_hash(<<~SQL, binds).first
              INSERT INTO #{@table} (#{quoted_columns.join(", ")})
              VALUES (#{placeholders.join(", ")})
              RETURNING *
            SQL
        end

      serialize_row(result)
    end

    def update(row_id, data)
      attributes = DataTableRow.normalize_row_data(@data_table, data, fill_missing: false)
      update_normalized(row_id, attributes)
    end

    def update_many(filter:, data:)
      normalized_filter = normalize_filter(filter, optional: false)
      attributes = DataTableRow.normalize_row_data(@data_table, data, fill_missing: false)
      update_many_normalized(filter: normalized_filter, data: attributes)
    end

    def update_normalized(row_id, data)
      raise DataTableValidationError, "Data columns must not be empty" if data.empty?

      assignments, binds = build_assignments(data)
      binds[:row_id] = row_id

      DB.query_hash(<<~SQL, binds).first&.then { |row| serialize_row(row) }
          UPDATE #{@table}
          SET #{assignments.join(", ")}, #{DataTableStorage.quoted_column("updated_at")} = CURRENT_TIMESTAMP
          WHERE #{DataTableStorage.quoted_column("id")} = :row_id
          RETURNING *
        SQL
    end

    def update_many_normalized(filter:, data:)
      raise DataTableValidationError, "Data columns must not be empty" if data.empty?

      where_clause, binds = build_where_clause(filter)
      assignments, assignment_binds = build_assignments(data)

      DB.exec(<<~SQL, binds.merge(assignment_binds))
        UPDATE #{@table}
        SET #{assignments.join(", ")}, #{DataTableStorage.quoted_column("updated_at")} = CURRENT_TIMESTAMP
        #{where_clause}
      SQL
    end

    def delete(row_id)
      DB.query_hash(<<~SQL, row_id: row_id).any?
          DELETE FROM #{@table}
          WHERE #{DataTableStorage.quoted_column("id")} = :row_id
          RETURNING #{DataTableStorage.quoted_column("id")}
        SQL
    end

    def delete_many(filter:)
      normalized_filter = normalize_filter(filter, optional: false)
      where_clause, binds = build_where_clause(normalized_filter)
      DB.exec("DELETE FROM #{@table}#{where_clause}", binds)
    end

    def upsert(filter:, data:)
      normalized_filter = normalize_filter(filter, optional: false)
      attributes = DataTableRow.normalize_row_data(@data_table, data, fill_missing: false)
      raise DataTableValidationError, "Data columns must not be empty" if attributes.empty?

      updated_count = update_many_normalized(filter: normalized_filter, data: attributes)

      if updated_count > 0
        { operation: "update", updated_count: updated_count }
      else
        { operation: "insert", row: insert(attributes) }
      end
    end

    private

    def normalize_filter(filter, optional:)
      DataTableFilter.new(@data_table, filter).normalize(optional: optional)
    end

    def build_where_clause(filter, optional: false)
      normalized_filter = filter.is_a?(Hash) ? filter : normalize_filter(filter, optional: optional)
      return "", {} if normalized_filter.blank? || normalized_filter["filters"].blank?

      joins = normalized_filter["type"] == "or" ? " OR " : " AND "
      clauses = []
      binds = {}

      normalized_filter["filters"].each_with_index do |condition, index|
        clause, clause_binds = build_condition(condition, index)
        clauses << clause
        binds.merge!(clause_binds)
      end

      [" WHERE #{clauses.join(joins)}", binds]
    end

    def build_condition(filter, index)
      column_name = filter["columnName"]
      condition = filter["condition"]
      value = filter["value"]
      column = quoted_column(column_name)
      bind_name = :"filter_#{index}"

      if value.nil?
        case condition
        when "eq"
          return "#{column} IS NULL", {}
        when "neq"
          return "#{column} IS NOT NULL", {}
        end
      end

      case condition
      when "eq"
        ["#{column} = :#{bind_name}", { bind_name => value }]
      when "neq"
        ["(#{column} != :#{bind_name} OR #{column} IS NULL)", { bind_name => value }]
      when "gt"
        ["#{column} > :#{bind_name}", { bind_name => value }]
      when "gte"
        ["#{column} >= :#{bind_name}", { bind_name => value }]
      when "lt"
        ["#{column} < :#{bind_name}", { bind_name => value }]
      when "lte"
        ["#{column} <= :#{bind_name}", { bind_name => value }]
      when "like"
        ["#{column} LIKE :#{bind_name} ESCAPE '!'", { bind_name => escape_like_specials(value) }]
      when "ilike"
        ["#{column} ILIKE :#{bind_name} ESCAPE '!'", { bind_name => escape_like_specials(value) }]
      else
        raise DataTableValidationError, "Unsupported filter condition '#{condition}'"
      end
    end

    def build_order_clause(sort_by, sort_direction)
      return "ORDER BY #{quoted_column("id")} ASC" if sort_by.blank?

      allowed_columns = @column_map.keys | %w[id created_at updated_at]
      if allowed_columns.exclude?(sort_by)
        raise DataTableValidationError, "Unknown sort column '#{sort_by}'"
      end

      direction = SORT_DIRECTIONS[sort_direction.to_s.downcase] || "ASC"

      <<~SQL.squish
        ORDER BY #{quoted_column(sort_by)} #{direction} NULLS LAST, #{quoted_column("id")} ASC
      SQL
    end

    def build_limit_clause(limit, binds)
      return "" if limit.blank?

      parsed_limit = [limit.to_i, MAX_LIMIT].min
      raise DataTableValidationError, "Limit must be greater than 0" if parsed_limit <= 0

      binds[:limit] = parsed_limit
      "LIMIT :limit"
    end

    def build_offset_clause(offset, binds)
      return "" if offset.blank?

      parsed_offset = offset.to_i
      return "" if parsed_offset <= 0

      binds[:offset] = parsed_offset
      "OFFSET :offset"
    end

    def build_assignments(attributes)
      assignments = []
      binds = {}

      attributes.each_with_index do |(column_name, value), index|
        bind_name = :"assignment_#{index}"
        assignments << "#{quoted_column(column_name)} = :#{bind_name}"
        binds[bind_name] = value
      end

      [assignments, binds]
    end

    def quoted_column(name)
      DataTableStorage.quoted_column(name)
    end

    def escape_like_specials(value)
      value.to_s.gsub(/[!_]/) { |match| "!#{match}" }
    end

    def serialize_row(row)
      row.each_with_object({}) { |(key, value), result| result[key] = serialize_value(key, value) }
    end

    def serialize_value(key, value)
      return nil if value.nil?

      if %w[created_at updated_at].include?(key) ||
           DiscourseWorkflows::DataTable.column_type(@column_map[key]) == "date"
        value.respond_to?(:iso8601) ? value.utc.iso8601 : value
      else
        value
      end
    end
  end
end

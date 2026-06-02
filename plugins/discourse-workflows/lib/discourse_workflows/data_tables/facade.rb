# frozen_string_literal: true

module DiscourseWorkflows
  module DataTables
    class Facade
      LOCK_TIMEOUT_MS = 5_000
      STATEMENT_TIMEOUT_MS = 500

      class StatementTimeout < StandardError
      end

      class Query
        include ActiveModel::Validations

        attr_reader :normalized_filter, :limit, :offset, :sort_by, :sort_direction

        validate :check_filter_errors

        def initialize(
          data_table:,
          filter: nil,
          limit: nil,
          offset: nil,
          sort_by: nil,
          sort_direction: nil,
          optional_filter: false
        )
          normalized_filter =
            DiscourseWorkflows::NormalizedFilter.new(
              data_table:,
              filter:,
              optional: optional_filter,
            )

          @invalid_filter = normalized_filter if normalized_filter.invalid?
          @normalized_filter = normalized_filter.value
          @limit = limit
          @offset = offset
          @sort_by = sort_by
          @sort_direction = sort_direction
        end

        def has_changes_to_save?
          true
        end

        private

        def check_filter_errors
          @invalid_filter&.errors&.full_messages&.each { |message| errors.add(:base, message) }
        end
      end

      class RowInput
        include ActiveModel::Validations

        attr_reader :columns

        validate :check_normalization_error

        def initialize(data_table:, data:, fill_missing: false)
          @columns = DataTableRow.normalize_row_data(data_table, data, fill_missing: fill_missing)
        rescue ArgumentError => e
          @normalization_error = e.message
          @columns = {}
        end

        def has_changes_to_save?
          true
        end

        private

        def check_normalization_error
          errors.add(:base, @normalization_error) if @normalization_error.present?
        end
      end

      MAX_TOTAL_SIZE_BYTES = 50.megabytes

      class << self
        def within_storage_limit?
          Storage.total_size_bytes < MAX_TOTAL_SIZE_BYTES
        end

        def total_size_bytes
          Storage.total_size_bytes
        end

        def batch_size_bytes(data_table_ids)
          Storage.batch_size_bytes(data_table_ids)
        end

        def size_bytes(data_table_id)
          Storage.size_bytes(data_table_id)
        end

        def create_table!(data_table, columns: [])
          Storage.create_table!(data_table, columns: columns)
        end

        def drop_table!(data_table_id)
          Storage.drop_table!(data_table_id)
        end
      end

      SORT_DIRECTIONS = { "asc" => "ASC", "desc" => "DESC" }.freeze
      MAX_LIMIT = 100

      attr_reader :data_table

      def initialize(data_table)
        @data_table = data_table
        @table_name = Storage.table_name(data_table.id)
        @table = Arel::Table.new(@table_name)
      end

      def build_query(**options)
        Query.new(data_table: @data_table, **options)
      end

      def build_row_input(**options)
        RowInput.new(data_table: @data_table, **options)
      end

      def query(query)
        with_statement_timeout { query_rows(query) }
      end

      def find_row(row_id)
        with_statement_timeout do
          query = @table.project(Arel.star).where(@table[:id].eq(row_id))
          connection.exec_query(query.to_sql).to_a.first&.then { |row| serialize_row(row) }
        end
      end

      def count(query = nil)
        with_statement_timeout { count_rows(normalized_filter: query&.normalized_filter) }
      end

      def insert(row_input)
        validate_storage_limit!
        with_statement_timeout { insert_row(row_input.columns) }
      end

      def update_row(row_id:, row_input:)
        return nil if row_input.columns.empty?

        validate_storage_limit!
        with_statement_timeout do
          um = build_update_manager(row_input.columns)
          um.where(@table[:id].eq(row_id))
          connection
            .exec_query("#{um.to_sql} RETURNING *")
            .to_a
            .first
            &.then { |row| serialize_row(row) }
        end
      end

      def update(query:, row_input:)
        return 0 if row_input.columns.empty?

        validate_storage_limit!
        with_statement_timeout do
          um = build_update_manager(row_input.columns)
          um = apply_filters(um, query.normalized_filter)
          connection.exec_update(um.to_sql)
        end
      end

      def delete(query:)
        with_statement_timeout do
          dm = Arel::DeleteManager.new
          dm.from(@table)
          dm = apply_filters(dm, query.normalized_filter)
          connection.exec_delete(dm.to_sql)
        end
      end

      def delete_rows(row_ids)
        return 0 if row_ids.empty?

        with_statement_timeout do
          dm = Arel::DeleteManager.new
          dm.from(@table)
          dm.where(@table[:id].in(row_ids))
          connection.exec_delete(dm.to_sql)
        end
      end

      def add_column!(name, type)
        with_lock_timeout do
          connection.add_column(@table_name, name, Storage::SCHEMA_TYPES.fetch(type))
        end
      end

      def rename_column!(old_name:, new_name:)
        with_lock_timeout { connection.rename_column(@table_name, old_name, new_name) }
      end

      def drop_column!(column_name)
        with_lock_timeout { connection.remove_column(@table_name, column_name) }
      end

      private

      def validate_storage_limit!
        return if self.class.within_storage_limit?
        raise ArgumentError, "Data table storage limit exceeded"
      end

      def query_rows(data_query)
        query = @table.project(Arel.star, Arel.sql("COUNT(*) OVER() AS _total_count"))
        query = apply_filters(query, data_query.normalized_filter)
        query = apply_ordering(query, data_query.sort_by, data_query.sort_direction)
        query = apply_pagination(query, data_query.limit, data_query.offset)

        results = connection.exec_query(query.to_sql).to_a
        total_count = results.first&.[]("_total_count") || 0
        rows = results.map { |row| serialize_row(row.except("_total_count")) }

        { rows: rows, count: total_count }
      end

      def count_rows(normalized_filter: nil)
        query = @table.project(Arel.star.count)
        query = apply_filters(query, normalized_filter)
        connection.exec_query(query.to_sql).rows.first.first.to_i
      end

      def insert_row(normalized_data)
        result =
          if normalized_data.empty?
            im = Arel::InsertManager.new
            im.into(@table)
            connection.exec_query("#{im.to_sql} DEFAULT VALUES RETURNING *").to_a.first
          else
            execute_insert(normalized_data)
          end

        serialize_row(result)
      end

      def execute_insert(normalized_data)
        im = Arel::InsertManager.new
        im.into(@table)
        im.insert(normalized_data.map { |name, value| [@table[name], value] })
        connection.exec_query("#{im.to_sql} RETURNING *").to_a.first
      end

      def build_update_manager(normalized_data)
        um = Arel::UpdateManager.new
        um.table(@table)
        assignments =
          normalized_data.map { |name, value| [@table[name], value] } +
            [[@table[:updated_at], Arel.sql("CURRENT_TIMESTAMP")]]
        um.set(assignments)
        um
      end

      def apply_filters(query, normalized_filter)
        return query if normalized_filter.blank? || normalized_filter["filters"].blank?

        conditions = normalized_filter["filters"].map { |f| build_arel_condition(f) }
        combiner = normalized_filter["type"] == "or" ? :or : :and
        query.where(conditions.reduce(combiner))
      end

      def apply_ordering(query, sort_by, sort_direction)
        return query.order(@table[:id].asc) if sort_by.blank?

        if valid_sort_columns.exclude?(sort_by.to_s)
          raise ArgumentError, "Invalid sort column: #{sort_by.inspect}"
        end

        direction = SORT_DIRECTIONS[sort_direction.to_s.downcase] || "ASC"
        query.order(
          Arel.sql("#{Storage.quoted_column(sort_by)} #{direction} NULLS LAST"),
          @table[:id].asc,
        )
      end

      def valid_sort_columns
        @valid_sort_columns ||= @data_table.columns.map { |c| c["name"] }.to_set
      end

      def apply_pagination(query, limit, offset)
        if limit.present?
          parsed_limit = [Integer(limit), MAX_LIMIT].min
          query = query.take(parsed_limit) if parsed_limit > 0
        end
        if offset.present?
          parsed_offset = Integer(offset)
          query = query.skip(parsed_offset) if parsed_offset > 0
        end
        query
      end

      def build_arel_condition(filter)
        col = @table[filter["columnName"]]
        value = filter["value"]

        return filter["condition"] == "eq" ? col.eq(nil) : col.not_eq(nil) if value.nil?

        case filter["condition"]
        when "eq"
          col.eq(value)
        when "neq"
          col.not_eq(value).or(col.eq(nil))
        when "gt"
          col.gt(value)
        when "gte"
          col.gteq(value)
        when "lt"
          col.lt(value)
        when "lte"
          col.lteq(value)
        when "like"
          col.matches(escape_like_specials(value), "!", true)
        when "ilike"
          col.matches(escape_like_specials(value), "!", false)
        when "not_ilike"
          col.does_not_match(escape_like_specials(value), "!", false)
        else
          raise ArgumentError, "Unknown filter condition: #{filter["condition"].inspect}"
        end
      end

      def escape_like_specials(value)
        "%#{ActiveRecord::Base.sanitize_sql_like(value.to_s, "!")}%"
      end

      def connection
        ActiveRecord::Base.connection
      end

      def serialize_row(row)
        row.transform_values { |value| serialize_value(value) }
      end

      def serialize_value(value)
        return nil if value.nil?

        value.respond_to?(:iso8601) ? value.utc.iso8601 : value
      end

      def with_lock_timeout
        connection.transaction do
          connection.execute("SET LOCAL lock_timeout = '#{LOCK_TIMEOUT_MS}ms'")
          yield
        end
      rescue PG::LockNotAvailable
        raise
      end

      def with_statement_timeout
        connection.transaction do
          connection.execute("SET LOCAL statement_timeout = '#{STATEMENT_TIMEOUT_MS}ms'")
          yield
        end
      rescue ActiveRecord::QueryCanceled
        raise StatementTimeout, "Data table query exceeded the maximum allowed execution time"
      end
    end
  end
end
